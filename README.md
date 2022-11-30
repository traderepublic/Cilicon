<p align="center">
	<a href="https://github.com/traderepublic/Cilicon/"><img width="350" src="https://user-images.githubusercontent.com/1622982/204773431-050cc008-029c-4ab1-98a6-9d4fc30d272d.png" alt="Cilicon" /></a><br /><br />
	Self-Hosted macOS CI on Apple Silicon<br /><br />
    <a href="#-about-cilicon">About</a>
  • <a href="#-getting-started">Getting Started</a>
  • <a href="#-maintenance">Maintenance</a>
  • <a href="#-ideas-for-the-future">Ideas for the Future</a>
  • <a href="#-join-us">Join Us</a>
</p>


## 🔁 About Cilicon

Cilicon is a macOS App that leverages Apple's [Virtualization Framework](https://developer.apple.com/documentation/virtualization) to create, provision and run ephemeral virtual machines with minimal setup or maintenance effort. You should be able to get up and running with your self-hosted CI in less than an hour.

Cilicon is based on the following simple cycle.

<p align="center">
<img width="500" alt="Cilicon Cycle" src="https://user-images.githubusercontent.com/1622982/204821334-d71a567a-6bc7-4a93-b87e-40a14195097c.png">
</br><i>The Cilicon Cycle</i>
</p>

### Duplicate Image

Cilicon creates a clone of your Virtual Machine bundle for each run. [APFS clones](https://developer.apple.com/documentation/foundation/file_system/about_apple_file_system) make this task extremely fast, even with large bundles.

### Provision Shared Folder

Depending on the provisioner you choose, Cilicon places files required by your Guest OS in your bundle's `Resources` folder.

The [Github Actions provisioner](/Cilicon/Provisioner/Github%20Actions/GithubActionsProvisioner.swift) provisions the image with the runner download URL, a registration token, the runner name and runner labels.

You may also opt out of using a provisioner by setting the provisioner type to `none`. This may work fine with services like Buildkite which use non-expiring registration tokens.

### Start Virtual Machine

Cilicon starts the Virtual Machine and automatically mounts the bundle's `Resources` folder on the Guest OS.

### Listen for Shutdown
Cilicon listens for a shutdown of the Guest OS and removes the used image before starting over.

<p align="center">
<img width="600" alt="Cilicon Cycle" src="https://user-images.githubusercontent.com/1622982/204568479-d17aae2e-a02f-4e3b-bed7-a6fe66860dab.gif">
</br><i>Cilicon Cycle: Running a sample job via Github Actions (2x playback)</i>
</p>

## 🚀 Getting Started
Currently Cilicon only supports Github Actions, as well as a provisioner-less mode.
The host as well as the guest system must be running macOS 13 or newer and, as the name implies, Cilicon only runs on Apple Silicon.

To get started download Cilicon and Cilicon Installer from the [latest release](https://github.com/traderepublic/Cilicon/releases/latest).

<details>
  <summary>📖 Terminology</summary> 
  <ul>
  	<li><code>Host OS</code> is the OS that runs the Cilicon App</li>
  	<li><code>Guest OS</code> is the Virtual Machine running through Cilicon</li>
  </ul>
</details>

### ✨ Creating a VM Bundle
To create VM Bundles, Cilicon comes with its own standalone App called "Cilicon Installer".

With it you can either install a previously downloaded IPSW file or download the latest available restore image directly from Apple.

The resulting `.bundle` file can be opened by right-clicking it in Finder and pressing "Show Package Contents".

<p align="left">
<img width="300" alt="Cilicon Installer Window" src="https://user-images.githubusercontent.com/1622982/204774660-3583a889-562b-4dfd-a2c0-89c90cc0873b.gif">
</p>

### ⚙️ Configuration

Cilicon expects a valid `cilicon.yml` file to be present in the Host OS's home directory.

To use the Github Actions provisioner you will need to create and install a new Github App with `Self-hosted runners` `Read & Write` permissions on the organization level and provide your config with the respective information.


``` yml
vmBundlePath: ~/CI/VM.bundle
provisioner:
  type: github
  config:
    appId: 123456
    organization: traderepublic
    privateKeyPath: ~/CI/github.pem
hardware:
  ramGigabytes: 16
  connectsToAudioDevice: false
directoryMounts:
  - hostPath: ~/CI/VM Cache
    guestFolder: Cache
autoTransferImageVolume: /Volumes/Cilicon Drive
numberOfRunsUntilHostReboot: 20
editorMode: false
```

For more information on available optional and required properties, see [Config.swift](/Cilicon/Config/Config.swift).

### 🔧 Setting up the Guest OS
Once you have created a new VM Bundle you will need to set it up. To do so, enable the `editorMode` in the `cilicon.yml` file.
This will disable bundle duplication, provisioning and automatic restarting after shutdown.

It will also mount the bundle's `Editor Resources` folder to `/Volumes/My Shared Files/Resources`, which is the same path that `Resources` will be mounted to outside of editor mode. You can use this to provide any dependencies like installers to your Guest OS during setup.
After clicking through the macOS setup screens you can set up your Guest OS:
- Enable automatic login
- Disable Automatic Software updates
- Disable any concept of screen locking or power saving
- Select the dummy `start.command` file as a launch item which will start the CI agent/runner when mounted to the actual `Resources` folder.
- Install any dependencies you may need, such as Xcode, Command line tools, brew, etc.

<details>
  <summary>Depending on your setup, you may also want to enable passwordless <code>sudo</code>.</summary> 

Enter visudo:

```
sudo visudo
```

Find the admin group permission section:
```
%admin          ALL = (ALL) ALL
```
	
Change to add `NOPASSWD:`:
```
%admin          ALL = (ALL) NOPASSWD: ALL
```
</details>

Once you've set up your Guest OS, close all applications and shut down the Guest OS.

You can always edit your bundle further using editor mode.

Once you have configured your Guest OS, you will need provision your `Resources` folder with a `start.command` script to be run outside of editor mode.
You can find examples in [VM Resources](/VM%20Resources).

### 🔨 Setting Up the Host OS
It is recommended to use Cilicon on a macOS device fully dedicated to the task, ideally one that is [freshly restored](https://support.apple.com/en-gb/guide/apple-configurator-mac/apdd5f3c75ad/mac).

- Transfer `Cilicon.app`, `VM.bundle`, `cilicon.yml` as well as any other files referenced by your config (e.g. Github private key) to your Host OS.
- Add `Cilicon.app` as a launch item
- Set up automatic Login
- Disable automatic software updates
- Run `sudo pmset -b sleep 0; sudo pmset -b disablesleep 1` to disable sleep
- Disable any concept of battery savings, screen lock, wallpaper etc.

## 🧑‍🔧 Maintenance
Cilicon strives to keep maintenance effort at a minimum with features like automatic system restarts and provisioning from external disks.

### Automatic Host OS Restart

Cilicon supports restarting the Host OS after a set number of runs.

To enable this, simply set the `numberOfRunsUntilHostReboot` property in your `cilicon.yml` file.

If you're using this feature you may want to consider disabling the macOS boot chime ("Play sound on startup" in system settings)

### Image provisioning via external drive
Cilicon supports interactionless copying of VM images from external drives to the Host OS. This feature can be enabled by setting the `autoTransferImageVolume` in your `cilicon.yml` file. The bundle must be on the root of the drive and named `VM.bundle`.

The Host machine will notify start and finish of the process by playing system sounds and unmount the volume after copying is complete.
The new image will be be used after the next run.

If the Guest VM is shut down while Cilicon is copying a bundle, it will wait for it to complete copying before restarting the image.

Due to the new Accessory Security features in Ventura, macOS will require explicit consent for USB drives to be mounted and for Cilicon to access the drive. Once you have accepted these prompts for the first time, you should be able to run the process without any interaction on the device.

## 🔮 Ideas for the Future

### Support for more Provisioners
We use Github Actions for our iOS builds at [Trade Republic](https://traderepublic.com) but would love to see Cilicon being used for other CI services as well.
Implementing support for more services should be easy by building on top of the `Provisioner` protocol.

### Automated Bundle provisioning over the network
Updating an image on your Host machines is simple and depending on your image size and transfer medium it's also relatively fast.
In the future Cilicon could automatically fetch new images from a defined server on the local network.

### Monitoring
A logging or monitoring concept would greatly improve identifying and troubleshooting any potential issues and provide the ability to notify the team in real time.

### Setup Scripts
A lot of the setup of both Host and Guest OS can be scripted. Providing scripts for common setups would greatly increate the time to get started with Cilicon.

## 👩‍💻 Join Us!

At [Trade Republic](https://traderepublic.com/), we are on a mission to democratize wealth. We set up millions of Europeans for wealth with fast, easy, and free access to capital markets. With over one million customers we are one of the largest savings platforms in Europe, with users holding over €6 billion on our platform. [Join us](https://traderepublic.com/careers?department=4026464003) to build the FinTech of the future.
