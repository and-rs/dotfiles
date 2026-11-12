import { Plugin } from "@opencode/plugin/tui";
import { installQuestionFocus } from "./highlight";

export default Plugin.define({
  id: "question-focus",
  setup: installQuestionFocus,
});
