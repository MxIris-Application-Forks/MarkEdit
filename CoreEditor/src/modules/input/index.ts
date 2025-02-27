import { EditorView } from '@codemirror/view';
import { editingState } from '../../common/store';
import { startCompletion, isPanelVisible } from '../completion';
import { isContentDirty } from '../history';
import { tokenizePosition } from '../tokenizer';
import { scrollCaretToVisible, scrollToSelection, selectedLineColumn, updateActiveLine } from '../../modules/selection';

import selectedRange from '../selection/selectedRanges';
import wrapBlock from './wrapBlock';

/**
 * Tokenize words at the click position, especially useful for languages like Chinese and Japanese.
 */
export function wordTokenizer() {
  return EditorView.mouseSelectionStyle.of((editor, event) => {
    if (tokenizePosition(event) === null) {
      return null;
    }

    // There isn't an async way to get selection in CodeMirror,
    // we simply just leave the selection as is and handle the updates in a "dblclick" event handler.
    return {
      get(_event, _extend, _multiple) { return editor.state.selection; },
      update(_update) { /* no-op */ },
    };
  });
}

/**
 * Give us an opportunity to intercept user inputs.
 *
 * @returns True to ignore the default behavior
 */
export function interceptInputs() {
  const marksToWrap = ['`', '*', '_', '~', '$'];

  return EditorView.inputHandler.of((editor, _from, _to, insert) => {
    // E.g., wrap "selection" as "*selection*"
    if (marksToWrap.includes(insert)) {
      return wrapBlock(insert, editor);
    }

    if ((window.config.suggestWhileTyping || isPanelVisible()) && insert.trim().length > 0) {
      // Typing suggestions for non-space insertions
      startCompletion({ afterDelay: 300 });
    } else if (isPanelVisible()) {
      // Cancel the completion for whitespace insertions
      window.nativeModules.completion.cancelCompletion();
    }

    // Fallback to default behavior
    return false;
  });
}

/**
 * Returns an extension that handles all the editor changes.
 */
export function observeChanges() {
  return EditorView.updateListener.of(update => {
    // Ignore all events when the editor is idle
    if (editingState.isIdle && window.editor.state.doc.length === 0) {
      return;
    }

    if (update.docChanged) {
      // Make sure the main selection is always centered for typewriter mode
      if (window.config.typewriterMode) {
        scrollToSelection('center');
      } else {
        // We need this because we have different line height for headings,
        // CodeMirror doesn't by default fix the offset issue.
        scrollCaretToVisible();
      }
    }

    // CodeMirror doesn't mark `selectionSet` true when selection is cut or replaced,
    // always check `docChanged` too.
    if (update.selectionSet || update.docChanged) {
      const hasSelection = selectedRange().some(range => !range.empty);
      const selectionStateChanged = editingState.hasSelection !== hasSelection;
      editingState.hasSelection = hasSelection;

      // We don't update active lines when composition is still ongoing.
      //
      // Instead, we will make an extra update after composition ended.
      if (editingState.compositionEnded && selectionStateChanged) {
        updateActiveLine(hasSelection);
      }

      // Handle native updates.
      //
      // It would be great if we could also provide the updated text here,
      // but it's time-consuming for large payload,
      // we want to be responsive for every key stroke.
      window.nativeModules.core.notifyViewDidUpdate({
        contentEdited: update.docChanged,
        compositionEnded: editingState.compositionEnded,
        isDirty: isContentDirty(),
        selectedLineColumn: selectedLineColumn(),
      });
    }
  });
}
