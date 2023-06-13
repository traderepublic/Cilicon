<p align="center">
	<a href="https://github.com/traderepublic/Cilicon/"><img width="350" src="https://user-images.githubusercontent.com/1622982/204773431-050cc008-029c-4ab1-98a6-9d4fc30d272d.png" alt="Cilicon" /></a><br /><br />
	Self-Hosted macOS CI on Apple Silicon<br /><br />
    <a href="#-about-cilicon">About</a>
  • <a href="#-getting-started">Getting Started</a>
  • <a href="#-maintenance">Maintenance</a>
  • <a href="#-ideas-for-the-future">Ideas for the Future</a>
  • <a href="#-join-us">Join Us</a>
</p>

## 💥 What's new in 2.0?
We're excited to announce a new major update to Cilicon! Here's a summary of what's new:
- While Cilicon 1.0 relied on a user-defined Login Item script in the VM, its new version now includes an SSH client and directly executes commands on the Guest OS
- Cilicon has partially adopted the [tart](https://github.com/cirruslabs/tart) image format and can automatically convert 1.0 images to it
- The integrated OCI client can download pre-built CI images that have been created with/for tart. We recommend their [tart-ventura-xcode](https://github.com/cirruslabs/macos-image-templates/pkgs/container/macos-ventura-xcode) images.

## 🔁 About Cilicon

Cilicon is a macOS App that leverages Apple's [Virtualization Framework](https://developer.apple.com/documentation/virtualization) to create, provision and run ephemeral virtual machines with minimal setup or maintenance effort. You should be able to get up and running with your self-hosted CI in minutes (not counting the initial image download).

<table>
  <tr>
    <td><img width="500" alt="Cilicon Cycle" src="https://github.com/traderepublic/Cilicon/assets/1622982/0774ad39-4c86-4f23-ab27-5be4c89fa8f8">
</br><p align="center"><i>The Cilicon Cycle</i></p></td>
    <td><img width="600" alt="Cilicon Cycle" src="https://github.com/traderepublic/Cilicon/assets/1622982/31a0e031-4938-4d42-bc75-6ee29269abe4">
</br><p align="center"><i>Running a sample job via GitHub Actions (2x playback)</i></p></td>
  </tr>
</table>

## 🚀 Getting Started

### ✨ Choosing a Source

Cilicon uses the `tart` container format and comes with an integrated OCI client to fetch images from the internet.

It's recommended to use the [publicly hosted images](https://github.com/cirruslabs/macos-image-templates/pkgs/container/macos-ventura-xcode), however you may create new images using one of the following:

- Using [tart](https://github.com/cirruslabs/tart/) (supports downloading, installing, editing, and uploading to OCI) - recommended
- Using Cilicon Installer (supports downloading and installing. Editing can be done in Cilicon by enabling `editorMode`)

### ⚙️ Configuration

Cilicon expects a valid `cilicon.yml` file to be present in the Host OS's home directory.
For more information on available optional and required properties, see [Config.swift](/Cilicon/Config/Config.swift).

#### GitHub Actions

To use the GitHub Actions provisioner you will need to [create and install a new GitHub App](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app) with `Self-hosted runners` `Read & Write` permissions on the organization level and download the private key file to be referenced in the configuration file.

``` yml
source: oci://ghcr.io/cirruslabs/macos-ventura-xcode:14.2
provisioner:
  type: github
  config:
    appId: <APP_ID>
    organization: <ORGANIZATION_SLUG>
    privateKeyPath: ~/github.pem
```
#### Buildkite Agent

To use the Buildkite Agent provisioner, simply set your agent token in the provisioner config.

``` yml
source: oci://ghcr.io/cirruslabs/macos-ventura-xcode:14.2
provisioner:
  type: buildkite
  config:
    agentToken: <AGENT_TOKEN>
```

#### Script

If you want to run a script (e.g. to start a runner that's not natively supported), you may use the `script` provisioner.

``` yml
provisioner:
  type: script
  config:
     run: |
     	echo "Hello World"
        sleep 10
```

### 🔨 Setting Up the Host OS
It is recommended to use Cilicon on a macOS device fully dedicated to the task, ideally one that is [freshly restored](https://support.apple.com/en-gb/guide/apple-configurator-mac/apdd5f3c75ad/mac).

- Transfer `Cilicon.app`, `cilicon.yml` as well as any other files referenced by your config (e.g. Local image, GitHub private key etc.) to your Host OS.
- Add `Cilicon.app` as a launch item
- Set up automatic Login
- Disable automatic software updates
- Run `sudo pmset -b sleep 0; sudo pmset -b disablesleep 1` to disable sleep
- Disable any concept of battery savings, screen lock, wallpaper etc.

## 🔮 Ideas for the Future

### Support for more Provisioners
We use GitHub Actions for our iOS builds at [Trade Republic](https://traderepublic.com) but would love to see Cilicon being used for other CI services as well.
Implementing support for more services should be easy by building on top of the `Provisioner` protocol.

### Monitoring
A logging or monitoring concept would greatly improve identifying and troubleshooting any potential issues and provide the ability to notify the team in real time.

## 👩‍💻 Join Us!

At [Trade Republic](https://traderepublic.com/), we are on a mission to democratize wealth. We set up millions of Europeans for wealth with fast, easy, and free access to capital markets. With over one million customers we are one of the largest savings platforms in Europe, with users holding over €6 billion on our platform. [Join us](https://traderepublic.com/careers?department=4026464003) to build the FinTech of the future.
