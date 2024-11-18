<p align="center">
	<a href="https://github.com/traderepublic/Cilicon/"><img width="350" src="https://user-images.githubusercontent.com/1622982/204773431-050cc008-029c-4ab1-98a6-9d4fc30d272d.png" alt="Cilicon" /></a><br /><br />
	Self-Hosted macOS CI on Apple Silicon<br /><br />
    <a href="#-about-cilicon">About</a>
  • <a href="#-getting-started">Getting Started</a>
  • <a href="#-ideas-for-the-future">Ideas for the Future</a>
  • <a href="#-join-us">Join Us</a>
</p>

> [!CAUTION]
> There seems to be an issue with swift-nio based SSH on macOS 15.X hosts. Please don't update your host OS if you rely on Cilicon for production CI. This issue only affects the host OS. Images may still be updated to 15.X.

<details><summary><h3>💥 What's new in 2.0?</h3></summary>
We're excited to announce a new major update to Cilicon! Here's a summary of what's new:
<ul>
        <li>While Cilicon 1.0 relied on a user-defined Login Item script in the VM, its new version now includes an SSH client and directly executes commands on the VM.</li>
        <li>Cilicon has partially adopted the <a href="https://github.com/cirruslabs/tart">tart</a> image format and can automatically convert 1.0 images to it.</li>
        <li>The integrated OCI client can download pre-built CI images that have been created with/for tart. We recommend their <a href="https://github.com/cirruslabs/macos-image-templates/pkgs/container/macos-sonoma-xcode">macos-sonoma-xcode</a> images.</li>
</ul>
<h4>Migrating from 1.0</h4>
<ul>
        <li>The config file schema has changed slightly. In most cases renaming the <code>vmBundlePath</code> property to <code>source</code> should suffice.</li>
        <li>When Cilicon detects a 1.0 image it will offer you to automatically convert it to the new format for you.</li>
	<li>When converting an image from the 1.0 format, you must enable SSH and set the respective credentials in the config (or use the default <code>admin:admin</code>).</li>
</ul>
</details>

## 🔁 About Cilicon

Cilicon is a macOS App that leverages Apple's [Virtualization Framework](https://developer.apple.com/documentation/virtualization) to create, provision and run ephemeral CI VMs with near-native performance. It currently supports Github Actions, Buildkite Agent, GitLab Runner and arbitrary scripts. Depending on your setup, should be able to get up and running with your self-hosted CI in minutes 🚀

Cilicon operates in a very simple cycle described below:

<table>
  <tr>
    <td><img width="500" alt="Cilicon Cycle" src="https://github.com/traderepublic/Cilicon/assets/1622982/0774ad39-4c86-4f23-ab27-5be4c89fa8f8">
</br><p align="center"><i>The Cilicon Cycle</i></p></td>
    <td><img width="600" alt="Cilicon Cycle" src="https://github.com/traderepublic/Cilicon/assets/1622982/31a0e031-4938-4d42-bc75-6ee29269abe4">
</br><p align="center"><i>Running a sample job via GitHub Actions (2x playback)</i></p></td>
  </tr>
</table>

## 🚀 Getting Started

To get started, download the latest release [here](https://github.com/traderepublic/Cilicon/releases/latest).

### ✨ Choosing a Source

Cilicon uses the `tart` container format and comes with an integrated [OCI](https://opencontainers.org/) client to fetch images from the internet.

It's recommended to use [publicly hosted images](https://github.com/cirruslabs/macos-image-templates/pkgs/container/macos-sonoma-xcode), however if you need to create or customize your own image, you may use [tart](https://github.com/cirruslabs/tart/).


#### ⚠️ Important
- When choosing an OCI hosted image, make sure to prepend the `oci://` scheme to the url. Cilicon will otherwise assume a local filesystem path.
- Don't use the `latest` tag when choosing an image version. Instead pick the specific version of Xcode you would like to have installed (e.g. `14.3`).
- Images downloaded via OCI will reside in the `~/.tart` folder which should be cleared of unused images periodically.
- Images with newer versions of macOS may be published with the same version of Xcode installed. In case you want to upgrade, you may need to manually delete the outdated image and start Cilicon again.

### ⚙️ Configuration

Cilicon expects a `cilicon.yml` file to be present in the Host OS's home directory.
For more information on all available settings see [Config.swift](/Cilicon/Config/Config.swift).

#### GitHub Actions

To use the GitHub Actions provisioner you will need to [create and install a new GitHub App](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app) with `Self-hosted runners` `Read & Write` permissions on the organization level and download the private key file to be referenced in the configuration file.

``` yml
source: oci://ghcr.io/cirruslabs/macos-sonoma-xcode:15.3
provisioner:
  type: github
  config:
    appId: <APP_ID>
    organization: <ORGANIZATION_SLUG>
    privateKeyPath: ~/github.pem
```
#### GitLab Runner

To use the GitLab Runner provisioner you will need to [create a runner with an authentication token](https://docs.gitlab.com/ee/ci/runners/runners_scope.html#create-a-shared-runner-with-an-authentication-token).

Minimal example:

``` yml
source: oci://ghcr.io/cirruslabs/macos-sonoma-xcode:15.3
provisioner:
  type: gitlab
  config:
    gitlabURL: <GITLAB_INSTANCE_URL>
    runnerToken: <RUNNER_TOKEN>
```

Full configuration:

``` yml
source: oci://ghcr.io/cirruslabs/macos-sonoma-xcode:15.3
provisioner:
  type: gitlab
  config:
    gitlabURL: <GITLAB_INSTANCE_URL>
    runnerToken: <RUNNER_TOKEN>
    executor: <EXECUTOR> # defaults to 'shell'
    maxNumberOfBuilds: <MAX_BUILDS> # defaults to '1'
    downloadLatest: <DOWNLOAD_LATEST> # defaults to 'true'
    downloadURL: <DOWNLOAD_URL> # defaults to GitLab official S3 bucket
    configToml: > # Advanced config as custom config.toml file to be appended to the basic config and copied to the runner.
      <CONFIG_TOML>
```

#### Buildkite Agent

To use the Buildkite Agent provisioner, simply set your agent token in the provisioner config.

``` yml
source: oci://ghcr.io/cirruslabs/macos-sonoma-xcode:15.3
provisioner:
  type: buildkite
  config:
    agentToken: <AGENT_TOKEN>
```

#### Script

If you want to run a script (e.g. to start a runner that's not natively supported), you may use the `script` provisioner.

``` yml
source: oci://ghcr.io/cirruslabs/macos-sonoma-xcode:15.3
provisioner:
  type: script
  config:
     run: |
     	echo "Hello World"
        sleep 10
```

### 🔨 Setting Up the Host OS
It is recommended to use Cilicon on a macOS device fully dedicated to the task, ideally one that is [freshly restored](https://support.apple.com/en-gb/guide/apple-configurator-mac/apdd5f3c75ad/mac).

If you don't want to host your machine locally, [OakHost](https://www.oakhost.net/) provides great value dedicated Macs and are kindly offering 10% off the first two months for new customers with the code `CILICON10` (Disclaimer: We do not receive any form of compensation from sharing this code).

- Transfer `Cilicon.app`, `cilicon.yml` as well as any other files referenced by your config (e.g. Local image, GitHub private key etc.) to your Host OS.
- Add `Cilicon.app` as a launch item
- Set up Automatic Login
- Disable automatic software updates
- Disable any concept of screen lock, battery saving etc.


## 🔮 Ideas for the Future

### Support for more Provisioners
We use GitHub Actions for our iOS builds at [Trade Republic](https://traderepublic.com) but would love to see Cilicon being used for other CI services as well.
Implementing support for more services should be easy by building on top of the `Provisioner` protocol.

### Running 2 VMs in parallel
Xcode builds often don't use all of the compute resources available. Therefore running 2 VMs im parallel (more are not possible due to a limitation of the Virtualization framework) would be a welcome addition.

### Monitoring
A logging or monitoring concept would greatly improve identifying and troubleshooting any potential issues and provide the ability to notify the team in real time.

## 👩‍💻 Join Us!

At [Trade Republic](https://traderepublic.com/), we are on a mission to democratize wealth. We set up millions of Europeans for wealth with fast, easy, and free access to capital markets. With over one million customers we are one of the largest savings platforms in Europe, with users holding over €6 billion on our platform. [Join us](https://traderepublic.com/careers?department=4026464003) to build the FinTech of the future.



> *Disclaimer*: Trade Republic is not affiliated with Cirrus Labs or their tart product
