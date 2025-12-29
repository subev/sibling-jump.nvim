// Test fixture for JSX conditional rendering and expressions
export default function TestConditionals() {
  const registered = true;
  const items = [1, 2, 3];

  return (
    <>
      <Header />
      {registered && <ConditionalComponent />}
      {!registered && <AlternativeComponent />}
      {registered ? <TernaryTrue /> : <TernaryFalse />}
      {registered && (
        <WrappedConditional />
      )}
      {items.map(item => <MappedItem key={item} />)}
      {renderDynamicContent()}
      <Footer />
    </>
  );
}

function renderDynamicContent() {
  return <DynamicContent />;
}

// Test fixture for complex nested conditionals
export function ComplexConditionals() {
  const user = { isAdmin: true };
  const count = 5;

  return (
    <div>
      <ComponentA />
      {user?.isAdmin && <AdminPanel />}
      {count > 0 && count < 10 && <RangeComponent />}
      {user.isAdmin ? (
        <AdminView />
      ) : (
        <UserView />
      )}
      <ComponentB />
    </div>
  );
}

// Test fixture for plain value expressions
export function PlainValueExpressions() {
  const title = "Title";
  const userName = "User";

  return (
    <div>
      <Header />
      {title}
      <Content />
      {userName}
      <Footer />
    </div>
  );
}
