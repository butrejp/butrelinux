import "@typespec/json-schema";

using TypeSpec.JsonSchema;

@jsonSchema("/modules/fedora-rpm-latest.json")
model FedoraRpmModuleLatest {
  ...FedoraRpmModuleV1;
}

@jsonSchema("/modules/fedora-rpm-v1.json")
model FedoraRpmModuleV1 {
  /** Install Fedora RPM packages into EL-based images by overriding DNF releasever. */
  type: "fedora-rpm" | "fedora-rpm@v1" | "fedora-rpm@latest";

  /** Fedora release version to use for DNF repository expansion. */
  releasever: string;

  /** List of links to .repo files to download into /etc/yum.repos.d/. */
  repos?: Array<string>;

  /** List of links to key files to import for installing from custom repositories. */
  keys?: Array<string>;

  /** List of RPM packages to install. */
  install?: Array<string>;
}