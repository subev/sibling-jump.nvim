// Test fixture for single statement inside if block
// Issue: pressing <C-k> from inside the if block should be no-op,
// but incorrectly jumps to the statement before the if

function testFunction() {
  const beforeIf = "statement before if";
  
  if (condition) {
    return false;
  }
  
  const afterIf = "statement after if";
}

// More complex case with nested structure
function complexCase() {
  const isExitPopupOpen = currentPopup?.id === "game-exit-confirm";
  if (isExitPopupOpen) {
    return false;
  }
  
  const isLeavingPage = true;
}
