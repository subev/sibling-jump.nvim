// Test fixture for import statement navigation

// Multi-line named imports
import {
  UserRepository,
  timezone,
  username,
  UserLifecycleService,
} from "~/domains/users";

// Single line named imports
import { foo, bar, baz } from "./utils";

// Single import
import { single } from "./single";

// Default import (not navigable with named imports)
import defaultExport from "./default";

// Mixed import
import defaultExport, { named1, named2 } from "./mixed";
