;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-invalid-user (err u102))
(define-constant err-invalid-record (err u103))
(define-constant err-already-registered (err u104))

;; Define data variables
(define-data-var admin principal tx-sender)
(define-data-var next-record-id uint u0)

;; Define data maps
(define-map doctors
    principal
    {
        verified: bool,
        hospital: (string-ascii 64),
    }
)

(define-map patients
    principal
    {
        name: (string-ascii 64),
        dob: uint,
        active: bool,
    }
)

(define-map medical-records
    uint
    {
        patient: principal,
        doctor: principal,
        diagnosis: (string-ascii 256),
        prescription: (string-ascii 256),
        timestamp: uint,
        valid: bool,
    }
)

(define-map prescriptions
    uint
    {
        record-id: uint,
        filled: bool,
        pharmacy: (optional principal),
        fill-date: (optional uint),
    }
)

(define-map authorized-pharmacies
    principal
    {
        name: (string-ascii 64),
        verified: bool,
    }
)

;; Administrative functions
(define-public (register-doctor
        (doctor-principal principal)
        (hospital (string-ascii 64))
    )
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) err-owner-only)
        (asserts! (is-none (map-get? doctors doctor-principal))
            err-already-registered
        )
        (ok (map-set doctors doctor-principal {
            verified: true,
            hospital: hospital,
        }))
    )
)

(define-public (register-pharmacy
        (pharmacy-principal principal)
        (name (string-ascii 64))
    )
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) err-owner-only)
        (asserts! (is-none (map-get? authorized-pharmacies pharmacy-principal))
            err-already-registered
        )
        (ok (map-set authorized-pharmacies pharmacy-principal {
            name: name,
            verified: true,
        }))
    )
)

;; Patient registration and management
(define-public (register-patient
        (name (string-ascii 64))
        (dob uint)
    )
    (begin
        (asserts! (is-none (map-get? patients tx-sender)) err-already-registered)
        (ok (map-set patients tx-sender {
            name: name,
            dob: dob,
            active: true,
        }))
    )
)

;; Medical record functions
(define-public (create-medical-record
        (patient-principal principal)
        (diagnosis (string-ascii 256))
        (prescription (string-ascii 256))
    )
    (let (
            (doctor (unwrap! (map-get? doctors tx-sender) err-not-authorized))
            (record-id (var-get next-record-id))
        )
        (asserts! (get verified doctor) err-not-authorized)
        (asserts! (is-some (map-get? patients patient-principal))
            err-invalid-user
        )
        (map-set medical-records record-id {
            patient: patient-principal,
            doctor: tx-sender,
            diagnosis: diagnosis,
            prescription: prescription,
            timestamp: burn-block-height,
            valid: true,
        })
        (map-set prescriptions record-id {
            record-id: record-id,
            filled: false,
            pharmacy: none,
            fill-date: none,
        })
        (var-set next-record-id (+ record-id u1))
        (ok record-id)
    )
)

(define-public (fill-prescription (record-id uint))
    (let (
            (pharmacy (unwrap! (map-get? authorized-pharmacies tx-sender)
                err-not-authorized
            ))
            (prescription (unwrap! (map-get? prescriptions record-id) err-invalid-record))
            (record (unwrap! (map-get? medical-records record-id) err-invalid-record))
        )
        (asserts! (get verified pharmacy) err-not-authorized)
        (asserts! (not (get filled prescription)) err-invalid-record)
        (asserts! (get valid record) err-invalid-record)
        (ok (map-set prescriptions record-id {
            record-id: record-id,
            filled: true,
            pharmacy: (some tx-sender),
            fill-date: (some burn-block-height),
        }))
    )
)

;; Read-only functions

(define-read-only (get-prescription-status (record-id uint))
    (ok (unwrap! (map-get? prescriptions record-id) err-invalid-record))
)

(define-private (is-valid-record (record {
    id: uint,
    value: {
        patient: principal,
        doctor: principal,
        diagnosis: (string-ascii 256),
        prescription: (string-ascii 256),
        timestamp: uint,
        valid: bool,
    },
}))
    (and
        (is-eq (get patient (get value record)) tx-sender)
        (get valid (get value record))
    )
)

;; Security enhancement: Revocation functions
(define-public (revoke-doctor (doctor-principal principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) err-owner-only)
        (match (map-get? doctors doctor-principal)
            doctor (ok (map-set doctors doctor-principal {
                verified: false,
                hospital: (get hospital doctor),
            }))
            err-invalid-user
        )
    )
)

(define-public (invalidate-record (record-id uint))
    (let ((record (unwrap! (map-get? medical-records record-id) err-invalid-record)))
        (asserts!
            (or
                (is-eq tx-sender (var-get admin))
                (is-eq tx-sender (get doctor record))
            )
            err-not-authorized
        )
        (ok (map-set medical-records record-id (merge record { valid: false })))
    )
)
