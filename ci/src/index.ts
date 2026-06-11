import { Container, Directory, Service, dag, func, object } from "@dagger.io/dagger"

const GLEAM_ERLANG = "ghcr.io/gleam-lang/gleam:v1.17.0-erlang-alpine"
const GLEAM_NODE = "ghcr.io/gleam-lang/gleam:v1.17.0-node-alpine"

const testDatabaseUrl =
  "postgres://postgres:postgres@postgres:5432/gleamhub_test?sslmode=disable"

function erlangProjectContainer(
  source: Directory,
  project: string,
  packages: string[],
): Container {
  let ctr = dag
    .container()
    .from(GLEAM_ERLANG)
    .withMountedDirectory("/repo", source)
    .withWorkdir(`/repo/${project}`)

  if (packages.length > 0) {
    ctr = ctr.withExec(["apk", "add", "--no-cache", ...packages])
  }

  return ctr.withExec([
    "sh",
    "-c",
    `echo '==> ${project}: gleam deps download' && gleam deps download`,
  ])
}

function nodeProjectContainer(source: Directory, project: string): Container {
  return dag
    .container()
    .from(GLEAM_NODE)
    .withMountedDirectory("/repo", source)
    .withWorkdir(`/repo/${project}`)
    .withExec([
      "sh",
      "-c",
      `echo '==> ${project}: gleam deps download' && gleam deps download`,
    ])
    .withExec([
      "sh",
      "-c",
      `echo '==> ${project}: npm install' && npm install`,
    ])
}

function runGleamTest(ctr: Container, project: string): Container {
  return ctr.withExec([
    "sh",
    "-c",
    `echo '==> ${project}: gleam test' && gleam test`,
  ])
}

function postgresService(): Service {
  return dag
    .container()
    .from("postgres:16-alpine")
    .withEnvVariable("POSTGRES_USER", "postgres")
    .withEnvVariable("POSTGRES_PASSWORD", "postgres")
    .withEnvVariable("POSTGRES_DB", "gleamhub_test")
    .withExposedPort(5432)
    .asService()
}

function testServer(source: Directory): Container {
  const postgres = postgresService()

  return runGleamTest(
    erlangProjectContainer(source, "server", [
      "git",
      "nodejs",
      "npm",
      "postgresql-client",
    ])
      .withServiceBinding("postgres", postgres)
      .withEnvVariable("TEST_DATABASE_URL", testDatabaseUrl)
      .withExec([
        "sh",
        "-c",
        [
          "echo '==> server: waiting for postgres'",
          "until pg_isready -h postgres -U postgres -d gleamhub_test; do sleep 1; done",
          "echo '==> server: dbmate migrate'",
          "cd /repo/server && DATABASE_URL=\"$TEST_DATABASE_URL\" DBMATE_MIGRATIONS_DIR=db/migrations npx --yes dbmate up",
        ].join(" && "),
      ]),
    "server",
  )
}

function testUi(source: Directory): Container {
  return runGleamTest(nodeProjectContainer(source, "ui"), "ui")
}

@object()
export class GleamhubCi {
  @func()
  async ci(source: Directory): Promise<string> {
    const common = await runGleamTest(
      erlangProjectContainer(source, "common", []),
      "common",
    ).stdout()
    const worker = await runGleamTest(
      erlangProjectContainer(source, "ci-worker", []),
      "ci-worker",
    ).stdout()
    const ui = await testUi(source).stdout()
    const server = await testServer(source).stdout()

    return [common, worker, ui, server].join("\n\n")
  }
}
