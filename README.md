## **Welcome to EasyCP!**

EasyCP is a simplified hosting control panel built on top of HestiaCP, designed to provide administrators an easy to use web and command line interface, enabling them to quickly deploy and manage web domains, mail accounts, DNS zones, and databases from one central dashboard without the hassle of manually deploying and configuring individual components or services.

### Why EasyCP?

EasyCP was created to address specific needs of hosting administrators:

1. **Simplified Codebase** - We streamlined HestiaCP by removing unnecessary components (like the built-in file manager) to reduce complexity and potential security vulnerabilities from third-party dependencies.

2. **Controlled Updates** - Unlike HestiaCP which auto-updates via the apt repository, EasyCP provides **manual control** over panel updates. Updates are managed directly through the panel's "Updates" section, giving you full control over when your panel is upgraded and preventing unexpected changes to your system.

## Features and Services

- Apache2 and NGINX with PHP-FPM
- Multiple PHP versions (5.6 - 8.4, 8.3 as default)
- DNS Server (Bind) with clustering capabilities
- POP/IMAP/SMTP mail services with Anti-Virus, Anti-Spam, and Webmail (ClamAV, SpamAssassin, Sieve, Roundcube)
- MariaDB/MySQL and/or PostgreSQL databases
- Let's Encrypt SSL support with wildcard certificates
- Firewall with brute-force attack detection and IP lists (iptables, fail2ban, and ipset).

## Supported platforms and operating systems

- **Ubuntu:** 24.04 LTS, 22.04 LTS

**NOTES:**

- EasyCP does not support 32 bit operating systems!
- EasyCP in combination with OpenVZ 7 or lower might have issues with DNS and/or firewall. If you use a Virtual Private Server we strongly advice you to use something based on KVM or LXC!

## Installing EasyCP

- **NOTE:** You must install EasyCP on top of a fresh operating system installation to ensure proper functionality.

While we have taken every effort to make the installation process and the control panel interface as friendly as possible (even for new users), it is assumed that you will have some prior knowledge and understanding in the basics how to set up a Linux server before continuing.

### Step 1: Log in

To start the installation, you will need to be logged in as **root** or a user with super-user privileges. You can perform the installation either directly from the command line console or remotely via SSH:

```bash
ssh root@your.server
```

### Step 2: Download

Download the installation script for the latest release:

```bash
wget https://raw.githubusercontent.com/script-php/hestiacp/release/install/hst-install.sh
```

If the download fails due to an SSL validation error, please be sure you've installed the ca-certificate package on your system - you can do this with the following command:

```bash
apt-get update && apt-get install ca-certificates
```

### Step 3: Run

To begin the installation process, simply run the script and follow the on-screen prompts:

```bash
bash hst-install.sh
```

You will receive a welcome email at the address specified during installation (if applicable) and on-screen instructions after the installation is completed to log in and access your server.

### Custom installation

You may specify a number of various flags during installation to only install the features in which you need. To view a list of available options, run:

```bash
bash hst-install.sh -h
```

Alternatively, You can use <https://hestiacp.com/install.html> which allows you to easily generate the installation command via GUI.

## How to upgrade an existing installation

EasyCP does not use automatic updates via the apt repository. Instead, updates are managed directly through the panel:

1. Log in to your EasyCP control panel
2. Navigate to **Server Settings > Updates**
3. Check for available updates
4. Click the update button to upgrade when you're ready

This approach gives you full control over when your panel is updated, allowing you to schedule upgrades at convenient times without unexpected automatic changes to your system.

## Issues & Support Requests

- If you encounter a general problem while using Hestia Control Panel and need help, please [visit our forum](https://forum.hestiacp.com/) to search for potential solutions or post a new thread where community members can assist.
- Bugs and other reproducible issues should be filed via GitHub by [creating a new issue report](https://github.com/script-php/hestiacp/issues) so that our developers can investigate further. Please note that requests for support will be redirected to our forum.

**IMPORTANT: We _cannot_ provide support for requests that do not describe the troubleshooting steps that have already been performed, or for third-party applications not related to Hestia Control Panel (such as WordPress). Please make sure that you include as much information as possible in your forum posts or issue reports!**

## Contributions

If you would like to contribute to the project, please [read our Contribution Guidelines](https://github.com/script-php/hestiacp/blob/release/CONTRIBUTING.md) for a brief overview of our development process and standards.

## Copyright

"EasyCP" is a simplified derivative of "Hestia Control Panel". 

EasyCP maintains compatibility with Hestia Control Panel's GPL v3 license while providing additional simplifications and features tailored for administrators who prefer manual control over their panel updates.

For more information about the original Hestia Control Panel, visit [hestiacp.com](https://hestiacp.com/).

## License

EasyCP is licensed under [GPL v3](https://github.com/script-php/hestiacp/blob/release/LICENSE) license, and is based on the [Hestia Control Panel](https://hestiacp.com/) project.
