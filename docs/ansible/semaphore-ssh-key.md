# Semaphore SSH Private Key

**Copy the entire block below (including BEGIN and END lines) into Semaphore's "Private Key" field:**

```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACC2z81e0U8dsrwcy47OZvnZLThag2ks2AlTSMGcbXb15AAAAJjgm9lZ4JvZ
WQAAAAtzc2gtZWQyNTUxOQAAACC2z81e0U8dsrwcy47OZvnZLThag2ks2AlTSMGcbXb15A
AAAEDKPA62TUShDH8jRIDw90y9ou6N0QwwgoYQvqlSqKLKMbbPzV7RTx2yvBzLjs5m+dkt
OFqDaSzYCVNIwZxtdvXkAAAAEHNlbWFwaG9yZUBkb2NrZXIBAgMEBQ==
-----END OPENSSH PRIVATE KEY-----
```

**Public Key (for reference):**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILbPzV7RTx2yvBzLjs5m+dktOFqDaSzYCVNIwZxtdvXk semaphore@docker
```

**Key Fingerprint:**
```
SHA256:ft8WOlP8ShPn4smHTKlQryaZDT6cfjePGUcrtOvGEfA
```

---

## How to Use in Semaphore:

1. In Semaphore, go to **Key Store** → **New Key**
2. Fill in:
   - **Key Name**: `Ansible`
   - **Type**: `SSH Key`
   - **Username**: `root`
   - **Passphrase**: Leave empty
   - **Private Key**: Copy the entire block from above (7 lines total)
3. Click **CREATE**

---

**Note**: This key is already added to:
- Ansible container (PCT-110 at 192.168.1.25)
- Proxmox host (pve2 at 192.168.1.8)
