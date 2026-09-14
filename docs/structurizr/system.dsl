workspace "Cilicon" "Self-hosted macOS CI on Apple Silicon — ephemeral VM host application" {
    !identifiers hierarchical

    model {
        operator = person "CI Platform Operator" "Configures cilicon.yml on the host Mac and watches the app window" "Operator"

        cilicon = softwareSystem "Cilicon" "macOS app that clones, boots and provisions an ephemeral macOS VM per CI job" {
            app = container "Cilicon App (SwiftUI)" "Loads cilicon.yml, renders VM framebuffer and the SSH log stream" "Swift 6, SwiftUI, AppKit"
            vmManager = container "VM Manager" "Owns the run cycle: pull image, clone bundle, boot VM, connect SSH, provision, tear down, repeat" "Swift, Virtualization.framework"
            ociClient = container "OCI Client & Layer Downloaders" "Pulls tart-format manifests and lz4 disk layers from an OCI registry" "Swift, URLSession, Compression"
            provisioners = container "Provisioners" "Per-CI-backend command builders executed over SSH inside the guest" "Swift"
            sshClient = container "SSH Client" "Password-authenticated SSH session used for preRun, provisioning, liveness probes and postRun" "Citadel / swift-nio-ssh"
            configStore = container "cilicon.yml" "Declarative host configuration: source, provisioner, hardware, mounts, SSH credentials" "YAML file in host home directory" "File"
            imageCache = container "Image Cache" "Downloaded master bundles (disk.img, nvram.bin, config.json) under $HOME/.tart/cache/OCIs" "APFS directory" "File"
            cloneBundle = container "VM Clone" "Per-run copy of the master bundle, deleted and recreated every cycle" "APFS directory" "File"
            guestVM = container "Ephemeral macOS Guest VM" "Runs the CI agent; discarded after the job" "Virtualization.framework, macOS arm64"
        }

        registry = softwareSystem "OCI Registry" "Hosts tart-format macOS images (e.g. ghcr.io/cirruslabs)" "External"
        githubApi = softwareSystem "GitHub API" "GitHub App auth and Actions runner registration tokens" "External"
        gitlab = softwareSystem "GitLab Instance" "Registers and dispatches jobs to gitlab-runner" "External"
        buildkite = softwareSystem "Buildkite" "Agent registration and job dispatch" "External"
        runnerDownloads = softwareSystem "Runner Binary Downloads" "GitHub runner release assets, GitLab S3 bucket, Buildkite install script" "External"
        hostOS = softwareSystem "macOS Host Services" "DHCP lease database and Apple Events restart" "External"

        operator -> cilicon.configStore "Writes configuration"
        operator -> cilicon.app "Launches and observes"

        cilicon.app -> cilicon.configStore "Reads and decodes at startup" "YAML"
        cilicon.app -> cilicon.vmManager "Starts the run cycle"
        cilicon.vmManager -> cilicon.ociClient "Requests image pull when source is oci://"
        cilicon.ociClient -> registry "Fetches manifest and blobs" "HTTPS"
        cilicon.ociClient -> cilicon.imageCache "Writes config.json, disk.img, nvram.bin"
        cilicon.vmManager -> cilicon.imageCache "Copies master bundle"
        cilicon.vmManager -> cilicon.cloneBundle "Creates per-run clone, deletes on cleanup"
        cilicon.vmManager -> cilicon.guestVM "Boots from clone" "Virtualization.framework"
        cilicon.vmManager -> hostOS "Reads /var/db/dhcpd_leases for guest IP; sends restart Apple Event"
        cilicon.vmManager -> cilicon.sshClient "Opens session, runs preRun/postRun and liveness probe"
        cilicon.sshClient -> cilicon.guestVM "Executes shell commands" "SSH, password auth"
        cilicon.vmManager -> cilicon.provisioners "Delegates provisioning"
        cilicon.provisioners -> cilicon.sshClient "Streams provisioning command"
        cilicon.provisioners -> githubApi "JWT app auth, runner registration token, runner download URLs" "HTTPS REST"
        cilicon.guestVM -> githubApi "Registers ephemeral runner and executes workflow job" "HTTPS"
        cilicon.guestVM -> gitlab "Runs single build via gitlab-runner" "HTTPS"
        cilicon.guestVM -> buildkite "Starts agent with --disconnect-after-job" "HTTPS"
        cilicon.guestVM -> runnerDownloads "Downloads runner/agent binaries" "HTTPS"
    }

    views {
        systemContext cilicon "SystemContext" {
            include *
            autoLayout tb
        }
        container cilicon "Containers" {
            include *
            autoLayout tb
        }
        styles {
            element "Person" {
                shape Person
                background #08427B
                color #ffffff
            }
            element "Software System" {
                background #1168BD
                color #ffffff
            }
            element "Container" {
                background #438DD5
                color #ffffff
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "File" {
                shape Folder
                background #6DB33F
                color #ffffff
            }
        }
    }
}
