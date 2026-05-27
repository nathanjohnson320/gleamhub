INSERT INTO organizations (slug, name)
VALUES ($1, $2)
RETURNING id::text, slug, name;
