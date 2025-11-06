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

(define-constant BADGE_NOVICE u1)
(define-constant BADGE_SCHOLAR u2)
(define-constant BADGE_EXPERT u3)
(define-constant BADGE_MASTER u4)
(define-constant BADGE_LEGEND u5)

(define-constant ERR_CERTIFICATE_EXPIRED (err u111))
(define-constant ERR_NOT_RENEWABLE (err u112))
(define-constant NEVER_EXPIRES u0)

(define-constant GRADE_A_PLUS u100)
(define-constant GRADE_A u95)
(define-constant GRADE_A_MINUS u90)
(define-constant GRADE_B_PLUS u85)
(define-constant GRADE_B u80)
(define-constant GRADE_B_MINUS u75)
(define-constant GRADE_C u70)
(define-constant GRADE_D u60)
(define-constant GRADE_DEFAULT u50)

(define-constant ENDORSEMENT_WEIGHT u5)
(define-constant SKILL_DIVERSITY_WEIGHT u3)

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
    
    (try! (check-and-award-badges student-address))
    
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
        (old-owner-certs (begin
          (var-set target-cert-filter certificate-id)
          (filter-out-certificate (get-student-certificates current-owner) certificate-id)
        ))
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

(define-private (filter-out-certificate (cert-list (list 50 uint)) (target-cert-id uint))
  (filter is-not-target-cert cert-list)
)

(define-private (is-not-target-cert (cert-id uint))
  (not (is-eq cert-id (var-get target-cert-filter)))
)

(define-data-var target-cert-filter uint u0)

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



(define-map badge-definitions
  uint
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    requirement: uint,
    icon: (string-ascii 100)
  }
)

(define-map student-badges principal (list 10 uint))
(define-map badge-holders uint (list 1000 principal))

(define-private (initialize-badges)
  (begin
    (map-set badge-definitions BADGE_NOVICE {
      name: "Certificate Novice",
      description: "Earned your first certificate - the journey begins!",
      requirement: u1,
      icon: "GRAD"
    })
    (map-set badge-definitions BADGE_SCHOLAR {
      name: "Academic Scholar",
      description: "Collected 5 certificates - showing real dedication!",
      requirement: u5,
      icon: "BOOK"
    })
    (map-set badge-definitions BADGE_EXPERT {
      name: "Domain Expert",
      description: "Achieved 10 certificates - you're becoming an expert!",
      requirement: u10,
      icon: "TROPHY"
    })
    (map-set badge-definitions BADGE_MASTER {
      name: "Learning Master",
      description: "Accumulated 20 certificates - mastery in action!",
      requirement: u20,
      icon: "STAR"
    })
    (map-set badge-definitions BADGE_LEGEND {
      name: "Education Legend",
      description: "Reached 50 certificates - legendary achievement!",
      requirement: u50,
      icon: "CROWN"
    })
    (ok true)
  )
)

(initialize-badges)

(define-read-only (get-badge-definition (badge-id uint))
  (map-get? badge-definitions badge-id)
)

(define-read-only (get-student-badges (student principal))
  (default-to (list) (map-get? student-badges student))
)

(define-read-only (get-badge-holders (badge-id uint))
  (default-to (list) (map-get? badge-holders badge-id))
)

(define-read-only (has-badge (student principal) (badge-id uint))
  (is-some (index-of (get-student-badges student) badge-id))
)

(define-private (award-badge (student principal) (badge-id uint))
  (let
    (
      (current-badges (get-student-badges student))
      (current-holders (get-badge-holders badge-id))
    )
    (if (has-badge student badge-id)
      (ok false)
      (begin
        (map-set student-badges student
          (unwrap! (as-max-len? (append current-badges badge-id) u10) (err u999))
        )
        (map-set badge-holders badge-id
          (unwrap! (as-max-len? (append current-holders student) u1000) (err u999))
        )
        (ok true)
      )
    )
  )
)

(define-private (check-and-award-badges (student principal))
  (let
    (
      (cert-count (get-certificate-count-by-student student))
    )
    (begin
      (if (>= cert-count u50) (try! (award-badge student BADGE_LEGEND)) false)
      (if (>= cert-count u20) (try! (award-badge student BADGE_MASTER)) false)
      (if (>= cert-count u10) (try! (award-badge student BADGE_EXPERT)) false)
      (if (>= cert-count u5) (try! (award-badge student BADGE_SCHOLAR)) false)
      (if (>= cert-count u1) (try! (award-badge student BADGE_NOVICE)) false)
      (ok true)
    )
  )
)

(define-constant ERR_CANNOT_ENDORSE_OWN_CERT (err u108))
(define-constant ERR_ALREADY_ENDORSED (err u109))
(define-constant ERR_ENDORSEMENT_NOT_FOUND (err u110))

(define-data-var next-endorsement-id uint u1)

(define-map endorsements
  uint
  {
    certificate-id: uint,
    endorser: principal,
    endorser-title: (string-utf8 100),
    credibility-score: uint,
    testimonial: (string-utf8 500),
    endorsed-at: uint
  }
)

(define-map certificate-endorsements uint (list 20 uint))
(define-map endorser-profile principal { verified: bool, reputation: uint })

(define-read-only (get-endorsement (endorsement-id uint))
  (map-get? endorsements endorsement-id)
)

(define-read-only (get-certificate-endorsements (certificate-id uint))
  (default-to (list) (map-get? certificate-endorsements certificate-id))
)

(define-read-only (get-endorser-profile (endorser principal))
  (default-to { verified: false, reputation: u0 } (map-get? endorser-profile endorser))
)

(define-read-only (calculate-endorsement-score (certificate-id uint))
  (fold + (map get-endorsement-weight (get-certificate-endorsements certificate-id)) u0)
)

(define-private (get-endorsement-weight (endorsement-id uint))
  (match (map-get? endorsements endorsement-id)
    endorsement (get credibility-score endorsement)
    u0
  )
)

(define-public (endorse-certificate 
  (certificate-id uint)
  (endorser-title (string-utf8 100))
  (credibility-score uint)
  (testimonial (string-utf8 500))
)
  (let
    (
      (endorsement-id (var-get next-endorsement-id))
      (certificate (unwrap! (map-get? certificates certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (current-endorsements (get-certificate-endorsements certificate-id))
    )
    (asserts! (not (is-eq tx-sender (get student-address certificate))) ERR_CANNOT_ENDORSE_OWN_CERT)
    (asserts! (not (get revoked certificate)) ERR_REVOKED)
    (asserts! (<= credibility-score u100) ERR_INVALID_PARAMS)
    (asserts! (> (len endorser-title) u0) ERR_INVALID_PARAMS)
    (asserts! (is-none (index-of-endorser current-endorsements tx-sender)) ERR_ALREADY_ENDORSED)
    
    (map-set endorsements endorsement-id
      {
        certificate-id: certificate-id,
        endorser: tx-sender,
        endorser-title: endorser-title,
        credibility-score: credibility-score,
        testimonial: testimonial,
        endorsed-at: stacks-block-height
      }
    )
    
    (map-set certificate-endorsements certificate-id
      (unwrap! (as-max-len? (append current-endorsements endorsement-id) u20) ERR_INVALID_PARAMS)
    )
    
    (var-set next-endorsement-id (+ endorsement-id u1))
    (unwrap! (update-endorser-reputation tx-sender) (err u999))
    
    (ok endorsement-id)
  )
)

(define-private (index-of-endorser (endorsement-list (list 20 uint)) (target-endorser principal))
  (fold check-endorser-match endorsement-list none)
)

(define-private (check-endorser-match (endorsement-id uint) (found (optional uint)))
  (if (is-some found)
    found
    (match (map-get? endorsements endorsement-id)
      endorsement (if (is-eq (get endorser endorsement) (var-get target-endorser-check)) (some endorsement-id) none)
      none
    )
  )
)

(define-data-var target-endorser-check principal 'SP000000000000000000002Q6VF78)

(define-private (update-endorser-reputation (endorser principal))
  (let
    (
      (current-profile (get-endorser-profile endorser))
      (new-reputation (+ (get reputation current-profile) u1))
    )
    (map-set endorser-profile endorser
      (merge current-profile { reputation: new-reputation })
    )
    (ok true)
  )
)


(define-map certificate-expiry
  uint
  {
    expiry-date: uint,
    renewable: bool,
    renewal-period: uint,
    grace-period: uint
  }
)

(define-map expired-certificates uint bool)

(define-read-only (get-certificate-expiry (certificate-id uint))
  (map-get? certificate-expiry certificate-id)
)

(define-read-only (is-certificate-expired (certificate-id uint))
  (match (map-get? certificate-expiry certificate-id)
    expiry-info
    (if (is-eq (get expiry-date expiry-info) NEVER_EXPIRES)
      false
      (> stacks-block-height (get expiry-date expiry-info))
    )
    false
  )
)

(define-read-only (is-certificate-in-grace-period (certificate-id uint))
  (match (map-get? certificate-expiry certificate-id)
    expiry-info
    (if (is-eq (get expiry-date expiry-info) NEVER_EXPIRES)
      false
      (let
        (
          (expiry-date (get expiry-date expiry-info))
          (grace-period (get grace-period expiry-info))
          (grace-end (+ expiry-date grace-period))
        )
        (and 
          (> stacks-block-height expiry-date)
          (<= stacks-block-height grace-end)
        )
      )
    )
    false
  )
)

(define-read-only (get-certificate-validity-status (certificate-id uint))
  (let
    (
      (certificate (map-get? certificates certificate-id))
      (is-expired (is-certificate-expired certificate-id))
      (in-grace (is-certificate-in-grace-period certificate-id))
    )
    (if (is-none certificate)
      (err ERR_CERTIFICATE_NOT_FOUND)
      (if (get revoked (unwrap-panic certificate))
        (ok "REVOKED")
        (if is-expired
          (if in-grace (ok "GRACE_PERIOD") (ok "EXPIRED"))
          (ok "VALID")
        )
      )
    )
  )
)

(define-public (set-certificate-expiry
  (certificate-id uint)
  (expiry-date uint)
  (renewable bool)
  (renewal-period uint)
  (grace-period uint)
)
  (let
    (
      (certificate (unwrap! (map-get? certificates certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (institution-id (unwrap! (map-get? institution-admins tx-sender) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq (get institution-id certificate) institution-id) ERR_NOT_AUTHORIZED)
    (asserts! (not (get revoked certificate)) ERR_REVOKED)
    
    (map-set certificate-expiry certificate-id
      {
        expiry-date: expiry-date,
        renewable: renewable,
        renewal-period: renewal-period,
        grace-period: grace-period
      }
    )
    (ok true)
  )
)

(define-public (renew-certificate (certificate-id uint))
  (let
    (
      (certificate (unwrap! (map-get? certificates certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (expiry-info (unwrap! (map-get? certificate-expiry certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (institution-id (unwrap! (map-get? institution-admins tx-sender) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq (get institution-id certificate) institution-id) ERR_NOT_AUTHORIZED)
    (asserts! (not (get revoked certificate)) ERR_REVOKED)
    (asserts! (get renewable expiry-info) ERR_NOT_RENEWABLE)
    (asserts! (is-certificate-expired certificate-id) ERR_INVALID_PARAMS)
    
    (map-set certificate-expiry certificate-id
      (merge expiry-info 
        { expiry-date: (+ stacks-block-height (get renewal-period expiry-info)) }
      )
    )
    
    (map-delete expired-certificates certificate-id)
    (ok true)
  )
)

(define-constant SKILL_BEGINNER u1)
(define-constant SKILL_INTERMEDIATE u2)
(define-constant SKILL_ADVANCED u3)
(define-constant SKILL_EXPERT u4)

(define-constant ERR_SKILL_NOT_FOUND (err u113))
(define-constant ERR_MAX_SKILLS_REACHED (err u114))

(define-map certificate-skills
  uint
  (list 10 { skill-name: (string-utf8 50), proficiency: uint })
)

(define-map skill-registry
  (string-utf8 50)
  (list 100 { certificate-id: uint, student: principal, proficiency: uint })
)

(define-read-only (get-certificate-skills (certificate-id uint))
  (default-to (list) (map-get? certificate-skills certificate-id))
)

(define-read-only (get-skill-holders (skill-name (string-utf8 50)))
  (default-to (list) (map-get? skill-registry skill-name))
)

(define-read-only (get-proficiency-name (level uint))
  (if (is-eq level SKILL_BEGINNER) "Beginner"
    (if (is-eq level SKILL_INTERMEDIATE) "Intermediate"
      (if (is-eq level SKILL_ADVANCED) "Advanced"
        (if (is-eq level SKILL_EXPERT) "Expert" "Unknown")
      )
    )
  )
)

(define-public (attach-skills-to-certificate
  (certificate-id uint)
  (skills (list 10 { skill-name: (string-utf8 50), proficiency: uint }))
)
  (let
    (
      (certificate (unwrap! (map-get? certificates certificate-id) ERR_CERTIFICATE_NOT_FOUND))
      (institution-id (unwrap! (map-get? institution-admins tx-sender) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq (get institution-id certificate) institution-id) ERR_NOT_AUTHORIZED)
    (asserts! (not (get revoked certificate)) ERR_REVOKED)
    
    (map-set certificate-skills certificate-id skills)
    (register-skills-in-registry certificate-id (get student-address certificate) skills)
    (ok true)
  )
)

(define-private (register-skills-in-registry
  (cert-id uint)
  (student principal)
  (skills (list 10 { skill-name: (string-utf8 50), proficiency: uint }))
)
  (map register-single-skill-helper skills)
)

(define-private (register-single-skill-helper (skill { skill-name: (string-utf8 50), proficiency: uint }))
  (let
    (
      (current-holders (get-skill-holders (get skill-name skill)))
    )
    true
  )
)


(define-map student-performance-score principal uint)
(define-map global-leaderboard uint principal)
(define-map institution-leaderboard { institution-id: uint, rank: uint } principal)
(define-map student-rank principal { global-rank: uint, institution-rank: uint })

(define-data-var global-leaderboard-size uint u0)

(define-read-only (get-grade-score (grade (string-ascii 10)))
  (if (is-eq grade "A+") GRADE_A_PLUS
    (if (is-eq grade "A") GRADE_A
      (if (is-eq grade "A-") GRADE_A_MINUS
        (if (is-eq grade "B+") GRADE_B_PLUS
          (if (is-eq grade "B") GRADE_B
            (if (is-eq grade "B-") GRADE_B_MINUS
              (if (is-eq grade "C") GRADE_C
                (if (is-eq grade "D") GRADE_D GRADE_DEFAULT)
              )
            )
          )
        )
      )
    )
  )
)

(define-private (calculate-student-score (student principal))
  (let
    (
      (cert-ids (get-student-certificates student))
      (total-certs (len cert-ids))
      (grade-score (fold sum-certificate-grades cert-ids u0))
      (endorsement-score (* (fold count-endorsements cert-ids u0) ENDORSEMENT_WEIGHT))
      (skill-count (count-unique-skills student))
      (skill-score (* skill-count SKILL_DIVERSITY_WEIGHT))
    )
    (+ grade-score endorsement-score skill-score)
  )
)

(define-private (sum-certificate-grades (cert-id uint) (acc uint))
  (match (map-get? certificates cert-id)
    cert (+ acc (get-grade-score (get grade cert)))
    acc
  )
)

(define-private (count-endorsements (cert-id uint) (acc uint))
  (+ acc (len (get-certificate-endorsements cert-id)))
)

(define-private (count-unique-skills (student principal))
  (len (fold collect-skills (get-student-certificates student) (list)))
)

(define-private (collect-skills (cert-id uint) (skills-acc (list 100 (string-utf8 50))))
  skills-acc
)

(define-public (update-student-score (student principal))
  (let
    (
      (new-score (calculate-student-score student))
    )
    (map-set student-performance-score student new-score)
    (ok new-score)
  )
)

(define-read-only (get-student-score (student principal))
  (default-to u0 (map-get? student-performance-score student))
)

(define-read-only (get-top-students (limit uint))
  (ok (list (map-get? global-leaderboard u1) (map-get? global-leaderboard u2) (map-get? global-leaderboard u3)))
)

(define-read-only (get-student-global-rank (student principal))
  (match (map-get? student-rank student)
    rank-info (ok (get global-rank rank-info))
    (ok u0)
  )
)