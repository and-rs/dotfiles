set shell := ["nu", "-c"]

default:
    just --list

qmlfmt:
  fd | lines | where $it =~ `\.qml` | each {|i| qmlformat -n -i -w 2 $i }

symlinks:
  dotbot -v -c install.conf.yaml
