// Test fixture for destructuring pattern navigation
function useTestHook() {
  const { registered } = useSessionContext();
  const {
    currentTab: tab,
    setCurrentTab,
    payload: tabPayload,
  } = useTab({
    defaultTab: "main",
  });
  const { currentSubTab } = useSubTab();
  
  return { tab, registered };
}
