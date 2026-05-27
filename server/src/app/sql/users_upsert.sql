INSERT INTO users (id, display_name, email)
VALUES ($1, $2, $3)
ON CONFLICT (id) DO UPDATE SET
  display_name = COALESCE(EXCLUDED.display_name, users.display_name),
  email = COALESCE(EXCLUDED.email, users.email);
