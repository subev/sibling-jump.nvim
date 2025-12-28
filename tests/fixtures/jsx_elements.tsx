// Test fixture for JSX element navigation
export default function TestComponent() {
  return (
    <>
      <HeaderContent
        sessionSource={null}
        currentTab="main"
      />
      <Header
        visible={true}
        variant="right"
      />
      <PersistentTabContainer visible={true} title="Explore">
        <DiscoverTab />
      </PersistentTabContainer>
      <TabContainer visible={false}>
        <ProfileTab />
      </TabContainer>
      <AnotherContainer>
        <Content />
      </AnotherContainer>
      <Footer />
    </>
  );
}
