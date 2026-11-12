#include "iconvalidator.hpp"

#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QIcon>
#include <QImage>
#include <QLoggingCategory>
#include <QTemporaryDir>
#include <atomic>
#include <cstdio>
#include <thread>

namespace {
std::atomic<int> svgWarnings{0};
std::atomic<int> otherWarnings{0};
Q_LOGGING_CATEGORY(svgLog, "qt.svg")

void captureMessage(QtMsgType type, const QMessageLogContext& context, const QString&) {
	if (type != QtWarningMsg)
		return;
	if (qstrcmp(context.category, "qt.svg") == 0)
		++svgWarnings;
	else
		++otherWarnings;
}

bool writeFile(const QString& path, const QByteArray& contents) {
	QFile file(path);
	return file.open(QIODevice::WriteOnly) && file.write(contents) == contents.size();
}

bool check(bool condition, const char* message) {
	if (!condition)
		std::fprintf(stderr, "FAIL: %s\n", message);
	return condition;
}
}  // namespace

int main(int argc, char** argv) {
	QGuiApplication app(argc, argv);
	QTemporaryDir theme;
	if (!check(theme.isValid(), "temporary theme directory"))
		return 1;
	const QString icons = theme.path() + "/test/32x32/apps";
	if (!check(QDir().mkpath(icons), "create icon directory") ||
	    !check(writeFile(theme.path() + "/test/index.theme",
	                     "[Icon Theme]\nName=Test\nDirectories=32x32/apps\n"
	                     "[32x32/apps]\nSize=32\nType=Fixed\nContext=Applications\n"),
	           "write theme index") ||
	    !check(writeFile(icons + "/valid.svg",
	                     "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"32\" height=\"32\">"
	                     "<rect width=\"32\" height=\"32\" fill=\"red\"/></svg>"),
	           "write valid SVG"))
		return 1;
	QImage png(32, 32, QImage::Format_ARGB32);
	png.fill(Qt::red);
	if (!check(png.save(icons + "/broken.svg", "PNG"), "write PNG with SVG extension"))
		return 1;
	QIcon::setThemeSearchPaths({theme.path()});
	QIcon::setThemeName("test");

	const auto originalHandler = qInstallMessageHandler(captureMessage);
	bool passed = true;
	{
		IconValidator validator;
		const QUrl valid("image://icon/valid");
		const QUrl broken("image://icon/broken");
		passed &= check(validator.isValid(valid, 32, 32), "valid SVG accepted");
		passed &= check(!validator.isValid(broken, 32, 32), "mislabeled PNG rejected");
		passed &= check(!validator.isValid(broken, 32, 32), "cached rejection preserved");
		validator.clearCache();
		passed &=
		    check(!validator.isValid(broken, 32, 32), "revalidation still rejects broken icon");
		passed &= check(svgWarnings == 0, "validation SVG warnings suppressed");
		IconValidator secondValidator;
		passed &= check(!secondValidator.isValid(broken, 32, 32),
		                "multiple validators share quiet handling");
		passed &= check(validator.isValid(QUrl("file:///unvalidated.png"), 32, 32),
		                "other URL schemes unchanged");
		QIcon::fromTheme("broken").pixmap(QSize(32, 32));
		passed &= check(svgWarnings > 0, "same broken icon warns outside validation");
		svgWarnings = 0;
		qCWarning(svgLog) << "outside validation";
		qWarning("unrelated warning");
		std::thread worker([] {
			for (int i = 0; i < 100; ++i)
				qCWarning(svgLog) << "other thread";
		});
		for (int i = 0; i < 100; ++i) {
			validator.clearCache();
			passed &= check(!validator.isValid(broken, 32, 32),
			                "concurrent logging does not change validation");
		}
		worker.join();
		passed &= check(svgWarnings == 101, "external SVG warnings forwarded to previous handler");
		passed &= check(otherWarnings == 1, "unrelated warnings forwarded to previous handler");
	}
	qCWarning(svgLog) << "after validator destruction";
	passed &= check(svgWarnings == 102, "forwarding survives validator destruction");
	qInstallMessageHandler(originalHandler);
	if (!passed)
		return 1;
	std::puts("PASS: icon validation, cache, quiet SVG checks, and warning forwarding");
	return 0;
}
