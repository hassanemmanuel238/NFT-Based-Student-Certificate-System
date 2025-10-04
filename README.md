# 🎓 NFT-Based Student Certificate System

> 🔐 **Verifiable Digital Credentials on the Blockchain**

A Clarity smart contract system that enables educational institutions to issue, manage, and verify student certificates as Non-Fungible Tokens (NFTs) on the Stacks blockchain.

## 🌟 Features

- 🏫 **Institution Management**: Register and manage educational institutions
- 🎯 **Certificate Issuance**: Mint certificates as NFTs to students
- ✅ **Certificate Verification**: Verify authenticity and validity of certificates
- 🔄 **Transfer Support**: Transfer certificate ownership between addresses
- 🚫 **Revocation System**: Revoke invalid or fraudulent certificates
- 📊 **Analytics**: Track certificate counts and institution statistics
- 🗂️ **IPFS Integration**: Store additional certificate metadata off-chain

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd NFT-Based-Student-Certificate-System
clarinet check
```

### Testing

```bash
clarinet test
```

## 📋 Contract Functions

### 🏫 Institution Management

#### `register-institution`
Register a new educational institution (Contract owner only).

```clarity
(contract-call? .contract register-institution "University Name")
```

#### `update-institution-admin`
Update the administrator of an institution.

```clarity
(contract-call? .contract update-institution-admin u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `toggle-institution-status`
Activate or deactivate an institution.

```clarity
(contract-call? .contract toggle-institution-status u1)
```

### 🎓 Certificate Management

#### `issue-certificate`
Issue a new certificate to a student (Institution admin only).

```clarity
(contract-call? .contract issue-certificate
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; student address
  u"John Doe"                                   ;; student name
  u"Computer Science Degree"                   ;; course name
  u12345                                       ;; completion date
  "A+"                                         ;; grade
  "QmXxx..."                                   ;; IPFS hash
)
```

#### `revoke-certificate`
Revoke a certificate (Institution admin only).

```clarity
(contract-call? .contract revoke-certificate u1)
```

#### `transfer-certificate`
Transfer certificate ownership to another address.

```clarity
(contract-call? .contract transfer-certificate u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### 🔍 Read-Only Functions

#### `verify-certificate`
Verify if a certificate is valid and not revoked.

```clarity
(contract-call? .contract verify-certificate u1)
```

#### `get-certificate`
Get certificate details by ID.

```clarity
(contract-call? .contract get-certificate u1)
```

#### `get-certificate-metadata`
Get formatted certificate metadata.

```clarity
(contract-call? .contract get-certificate-metadata u1)
```

#### `get-student-certificates`
Get all certificates owned by a student.

```clarity
(contract-call? .contract get-student-certificates 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `get-institution-certificates`
Get all certificates issued by an institution.

```clarity
(contract-call? .contract get-institution-certificates u1)
```

## 🏗️ Data Structures

### Institution
```clarity
{
  name: (string-ascii 100),
  admin: principal,
  active: bool,
  created-at: uint
}
```

### Certificate
```clarity
{
  student-address: principal,
  institution-id: uint,
  student-name: (string-utf8 100),
  course-name: (string-utf8 100),
  issue-date: uint,
  completion-date: uint,
  grade: (string-ascii 10),
  ipfs-hash: (string-ascii 64),
  revoked: bool,
  issuer: principal
}
```

## 🛡️ Security Features

- **Role-based Access Control**: Only contract owner can register institutions
- **Institution Authorization**: Only institution admins can issue/revoke certificates
- **Ownership Verification**: Only certificate owners can transfer certificates
- **Revocation Protection**: Revoked certificates cannot be transferred
- **Data Validation**: Input validation for all parameters

## 📈 Usage Examples

### Typical Workflow

1. **Setup Institution** 📚
   ```clarity
   ;; Contract owner registers university
   (contract-call? .contract register-institution "MIT")
   ```

2. **Issue Certificate** 🎯
   ```clarity
   ;; Institution admin issues certificate
   (contract-call? .contract issue-certificate
     'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
     u"Alice Smith"
     u"Blockchain Development Certificate"
     u1672531200
     "A"
     "QmCertificateMetadata123")
   ```

3. **Verify Certificate** ✅
   ```clarity
   ;; Anyone can verify certificate authenticity
   (contract-call? .contract verify-certificate u1)
   ```

4. **Transfer Certificate** 🔄
   ```clarity
   ;; Student transfers certificate to new address
   (contract-call? .contract transfer-certificate u1 'SP3NEWADDRESS...)
   ```

## 🔧 Error Codes

| Code | Description |
|------|-------------|
| u100 | Not contract owner |
| u101 | Not authorized |
| u102 | Certificate not found |
| u103 | Already exists |
| u104 | Invalid parameters |
| u105 | Certificate revoked |
| u106 | Institution not found |
| u107 | Institution inactive |

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Make your changes
4. Test thoroughly with `clarinet test`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🎯 Use Cases

- **Universities**: Issue degree certificates
- **Online Courses**: Verify course completion
- **Professional Training**: Certify skill acquisition
- **Bootcamps**: Validate program completion
- **Employers**: Verify candidate credentials

---

*Built with ❤️ using Clarity and Stacks blockchain*
