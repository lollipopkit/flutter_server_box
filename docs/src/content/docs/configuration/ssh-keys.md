---
title: SSH Keys
description: Set up SSH key authentication
---

SSH key authentication provides secure, passwordless access to your servers.

## Generating SSH Keys

### On Desktop

```bash
# Generate new key pair
ssh-keygen -t ed25519 -C "flutter_server_box"

# Or RSA for older systems
ssh-keygen -t rsa -b 4096 -C "flutter_server_box"
```

### Using the App

1. Go to Settings > SSH Keys
2. Tap **Generate New Key**
3. Choose key type (ED25519 recommended)
4. Enter optional passphrase
5. Key is generated and stored

## Adding Public Key to Server

### Method 1: Copy and Paste

1. Copy public key from app (Settings > SSH Keys)
2. SSH into server: `ssh user@server`
3. Add to `~/.ssh/authorized_keys`:
   ```bash
   mkdir -p ~/.ssh
   echo "PASTE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```

### Method 2: ssh-copy-id

```bash
ssh-copy-id -i ~/.ssh/my_key.pub user@server
```

### Method 3: Manual File Transfer

1. Copy public key from app
2. Use SFTP to upload to `~/.ssh/authorized_keys`
3. Set correct permissions

## Importing Existing Keys

### From File

1. Go to Settings > SSH Keys
2. Tap **Import Key**
3. Select private key file
4. Enter passphrase if required

### From Clipboard

1. Copy private key content
2. Paste into app when importing
3. Save key

## Using Keys with Servers

1. Add or edit server
2. In Authentication section, select **SSH Key**
3. Choose the key from the list
4. Save server configuration

## Key Security

- Private keys are stored encrypted
- Keys never leave the device
- Biometric authentication for key access
- Keys require passphrase (optional but recommended)

## Supported Key Types

- **ED25519**: Recommended (modern, secure, fast)
- **RSA**: 2048-bit minimum, 4096-bit recommended
- **ECDSA**: Supported but not recommended

## Troubleshooting

### Permission Denied

- Verify public key is in `~/.ssh/authorized_keys`
- Check file permissions (700 for .ssh, 600 for authorized_keys)
- Ensure SSH server allows key authentication

### Key Not Recognized

- Check key type is supported by server
- Verify key format is correct
- Try regenerating key pair
