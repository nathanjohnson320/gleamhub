import { dag, Container, Directory, object, func } from "@dagger.io/dagger"

@object()
class DemoCi {
  @func()
  ci(source: Directory): string {
    return dag
      .container()
      .from("alpine:3.21")
      .withMountedDirectory("/src", source)
      .withWorkdir("/src")
      .withExec(["sh", "-c", "test -f README.md && echo ok"])
      .stdout()
  }
}

export default DemoCi
