// Test fixture for JSX attribute navigation
export default function ComponentWithAttributes() {
  return (
    <div
      className="container"
      style={{ padding: 10 }}
      onClick={() => console.log("click")}
      data-testid="test"
      aria-label="Label"
    >
      <Button
        variant="primary"
        size="large"
        disabled={false}
        onClick={handleClick}
      />
    </div>
  );
}
