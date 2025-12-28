// Test file for type alias and interface declarations

type BaseItem = {
  id: string;
  name: string;
};

type RecentPlayedItem = BaseItem & {
  type: "recently_played";
  lastPlayedAt: string;
};

type NotificationItem = BaseItem & {
  type: "notification";
  notification: {
    id: string;
    status: string;
  };
};

interface UserProfile {
  userId: string;
  email: string;
}

interface AdminProfile extends UserProfile {
  role: "admin";
  permissions: string[];
}
