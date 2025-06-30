(define-non-fungible-token student-certificate uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_OWNER (err u100))
(define-constant ERR_NOT_AUTHORIZED (err u101))
(define-constant ERR_CERTIFICATE_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INVALID_PARAMS (err u104))
(define-constant ERR_REVOKED (err u105))
(define-constant ERR_INSTITUTION_NOT_FOUND (err u106))
(define-constant ERR_INSTITUTION_INACTIVE (err u107))

(define-data-var next-certificate-id uint u1)
(define-data-var next-institution-id uint u1)

(define-map institutions
  uint
  {
    name: (string-ascii 100),
    admin: principal,
    active: bool,
    created-at: uint
  }
)

(define-map certificates
  uint
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
)

(define-map institution-admins principal uint)
(define-map student-certificates principal (list 50 uint))
(define-map institution-certificates uint (list 1000 uint))

(define-read-only (get-contract-owner)
  CONTRACT_OWNER
)

(define-read-only (get-next-certificate-id)
  (var-get next-certificate-id)
)

(define-read-only (get-next-institution-id)
  (var-get next-institution-id)
)

(define-read-only (get-institution (institution-id uint))
  (map-get? institutions institution-id)
)

(define-read-only (get-certificate (certificate-id uint))
  (map-get? certificates certificate-id)
)

(define-read-only (get-certificate-owner (certificate-id uint))
  (nft-get-owner? student-certificate certificate-id)
)

(define-read-only (is-institution-admin (user principal))
  (is-some (map-get? institution-admins user))
)

(define-read-only (get-user-institution (user principal))
  (map-get? institution-admins user)
)

(define-read-only (get-student-certificates (student principal))
  (default-to (list) (map-get? student-certificates student))
)

(define-read-only (get-institution-certificates (institution-id uint))
  (default-to (list) (map-get? institution-certificates institution-id))
)

(define-read-only (verify-certificate (certificate-id uint))
  (match (map-get? certificates certificate-id)
    certificate
    (begin
      (asserts! (not (get revoked certificate)) (err ERR_REVOKED))
      (ok certificate)
    )
    (err ERR_CERTIFICATE_NOT_FOUND)
  )
)

(define-read-only (get-certificate-count-by-institution (institution-id uint))
  (len (get-institution-certificates institution-id))
)

(define-read-only (get-certificate-count-by-student (student principal))
  (len (get-student-certificates student))
)

(define-public (register-institution (name (string-ascii 100)))
  (let
    (
      (institution-id (var-get next-institution-id))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (asserts! (> (len name) u0) ERR_INVALID_PARAMS)
    
    (map-set institutions institution-id
      {
        name: name,
        admin: tx-sender,
        active: true,
        created-at: stacks-block-height
      }
    )
    
    (map-set institution-admins tx-sender institution-id)
    (var-set next-institution-id (+ institution-id u1))
    
    (ok institution-id)
  )
)

(define-public (update-institution-admin (institution-id uint) (new-admin principal))
  (let
    (
      (institution (unwrap! (map-get? institutions institution-id) ERR_INSTITUTION_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    
    (map-delete institution-admins (get admin institution))
    (map-set institution-admins new-admin institution-id)
    
    (map-set institutions institution-id
      (merge institution { admin: new-admin })
    )
    
    (ok true)
  )
)

(define-public (toggle-institution-status (institution-id uint))
  (let
    (
      (institution (unwrap! (map-get? institutions institution-id) ERR_INSTITUTION_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    
    (map-set institutions institution-id
      (merge institution { active: (not (get active institution)) })
    )
    
    (ok true)
  )
)

(define-public (issue-certificate 
  (student-address principal)
  (student-name (string-utf8 100))
  (course-name (string-utf8 100))
  (completion-date uint)
  (grade (string-ascii 10))
  (ipfs-hash (string-ascii 64))
)
  (let
    (
      (certificate-id (var-get next-certificate-id))
      (institution-id (unwrap! (map-get? institution-admins tx-sender) ERR_NOT_AUTHORIZED))
      (institution (unwrap! (map-get? institutions institution-id) ERR_INSTITUTION_NOT_FOUND))
    )
    (asserts! (get active institution) ERR_INSTITUTION_INACTIVE)
    (asserts! (> (len student-name) u0) ERR_INVALID_PARAMS)
    (asserts! (> (len course-name) u0) ERR_INVALID_PARAMS)
    (asserts! (> (len grade) u0) ERR_INVALID_PARAMS)
    
    (try! (nft-mint? student-certificate certificate-id student-address))
    
    (map-set certificates certificate-id
      {
        student-address: student-address,
        institution-id: institution-id,
        student-name: student-name,
        course-name: course-name,
        issue-date: stacks-block-height,
        completion-date: completion-date,
        grade: grade,
        ipfs-hash: ipfs-hash,
        revoked: false,
        issuer: tx-sender
      }
    )
    
    (let
      (
        (current-student-certs (get-student-certificates student-address))
        (current-institution-certs (get-institution-certificates institution-id))
      )
      (map-set student-certificates student-address
        (unwrap! (as-max-len? (append current-student-certs certificate-id) u50) ERR_INVALID_PARAMS)
      )
      (map-set institution-certificates institution-id
        (unwrap! (as-max-len? (append current-institution-certs certificate-id) u1000) ERR_INVALID_PARAMS)
      )
    )
    
    (var-set next-certificate-id (+ certificate-id u1))
    
    (ok certificate-id)
  )
)

(define-public (revoke-certificate (certificate-id uint))
  (let
    (
      (certificate (unwrap! (map-get? certificates certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (institution-id (unwrap! (map-get? institution-admins tx-sender) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq (get institution-id certificate) institution-id) ERR_NOT_AUTHORIZED)
    (asserts! (not (get revoked certificate)) ERR_REVOKED)
    
    (map-set certificates certificate-id
      (merge certificate { revoked: true })
    )
    
    (ok true)
  )
)

(define-public (transfer-certificate (certificate-id uint) (new-owner principal))
  (let
    (
      (current-owner (unwrap! (nft-get-owner? student-certificate certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (certificate (unwrap! (map-get? certificates certificate-id) ERR_CERTIFICATE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender current-owner) ERR_NOT_AUTHORIZED)
    (asserts! (not (get revoked certificate)) ERR_REVOKED)
    
    (try! (nft-transfer? student-certificate certificate-id current-owner new-owner))
    
    (map-set certificates certificate-id
      (merge certificate { student-address: new-owner })
    )
    
    (let
      (
        (old-owner-certs (filter-out-certificate (get-student-certificates current-owner) certificate-id))
        (new-owner-certs (get-student-certificates new-owner))
      )
      (map-set student-certificates current-owner old-owner-certs)
      (map-set student-certificates new-owner
        (unwrap! (as-max-len? (append new-owner-certs certificate-id) u50) ERR_INVALID_PARAMS)
      )
    )
    
    (ok true)
  )
)

(define-private (filter-out-certificate (cert-list (list 50 uint)) (cert-id uint))
  (filter is-not-target-cert cert-list)
)

(define-private (is-not-target-cert (cert-id uint))
  (not (is-eq cert-id cert-id))
)

(define-public (get-certificate-metadata (certificate-id uint))
  (match (map-get? certificates certificate-id)
    certificate
    (ok {
      certificate-id: certificate-id,
      student-address: (get student-address certificate),
      student-name: (get student-name certificate),
      course-name: (get course-name certificate),
      institution-name: (match (map-get? institutions (get institution-id certificate))
        institution (get name institution)
        "Unknown Institution"
      ),
      issue-date: (get issue-date certificate),
      completion-date: (get completion-date certificate),
      grade: (get grade certificate),
      revoked: (get revoked certificate),
      ipfs-hash: (get ipfs-hash certificate)
    })
    (err ERR_CERTIFICATE_NOT_FOUND)
  )
)

(define-read-only (get-total-certificates)
  (- (var-get next-certificate-id) u1)
)

(define-read-only (get-total-institutions)
  (- (var-get next-institution-id) u1)
)
