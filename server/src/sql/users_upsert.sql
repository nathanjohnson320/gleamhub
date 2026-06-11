INSERT INTO users (id, display_name, email)
VALUES ($1, $2, $3)
ON CONFLICT (id) DO UPDATE SET
  display_name = COALESCE(
    NULLIF(TRIM(EXCLUDED.display_name), ''),
    NULLIF(TRIM(users.display_name), '')
  ),
  email = COALESCE(
    NULLIF(TRIM(EXCLUDED.email), ''),
    NULLIF(TRIM(users.email), '')
  );
