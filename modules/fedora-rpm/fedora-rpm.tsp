import "@typespec/json-schema";
using TypeSpec.JsonSchema;

@jsonSchema("/modules/fedora-rpm-latest.json")
model FedoraRpmModuleLatest {
  ...FedoraRpmModuleV1;
}

@jsonSchema("/modules/fedora-rpm-v1.json")
model FedoraRpmModuleV1 {
  /**
   * Install RPM packages from an alternate RPM repository universe.
   *
   * Intended for cases such as installing Fedora RPMs into
   * CentOS Stream / EL based bootc images.
   */
  type: "fedora-rpm" | "fedora-rpm@v1" | "fedora-rpm@latest";

  /**
   * RPM repository release version to use instead of the host OS version.
   *
   * Example: "44" when consuming Fedora 44 COPR repositories from EL10.
   */
  releasever?: string;

  /**
   * Repository files to download into /etc/yum.repos.d/
   */
  repos?: Array<string>;

  /**
   * RPM packages to install.
   */
  install?: Array<string>;
}
