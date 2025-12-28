// Test fixture for TypeScript type property navigation
type GameProps = {
  game?: {
    contentUrl: string;
    slug: string;
    type: string;
    name: string;
    image: string | null;
    logo: string | null;
    color: string | undefined;
    id: string;
    description?: string | null;
  };
  sessionSource?: string | null;
  baseUrl: string;
};
