SELECT id::text, slug, name
FROM organizations
WHERE slug = $1;
