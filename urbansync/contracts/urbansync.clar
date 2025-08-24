;; Smart City Resource Management System
;; Manages city resources like parking, waste management, and energy

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INVALID-RESOURCE (err u2))
(define-constant ERR-RESOURCE-UNAVAILABLE (err u3))
(define-constant ERR-INVALID-PARAMS (err u4))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u5))
(define-constant ERR-DEVICE-NOT-FOUND (err u6))
(define-constant ERR-INVALID-CAPACITY (err u7))
(define-constant ERR-INVALID-PRICE (err u8))
(define-constant ERR-INVALID-LOCATION (err u9))
(define-constant ERR-INVALID-VEHICLE (err u10))
(define-constant ERR-INVALID-DEVICE (err u11))

;; Resource Types
(define-constant RESOURCE-TYPE-PARKING u1)
(define-constant RESOURCE-TYPE-WASTE u2)
(define-constant RESOURCE-TYPE-ENERGY u3)

;; Configuration Constants
(define-constant MAX-CAPACITY u1000000)
(define-constant MAX-PRICE u1000000000)

;; Data Variables
(define-data-var admin principal tx-sender)
(define-data-var resource-count uint u0)
(define-data-var min-parking-fee uint u1000) ;; in microSTX
(define-data-var energy-rate uint u100) ;; cost per kWh in microSTX

;; Maps
(define-map resources
    uint
    {
        resource-type: uint,
        location: (string-utf8 64),
        capacity: uint,
        available: uint,
        active: bool,
        price: uint
    }
)

(define-map parking-spots
    uint
    {
        spot-id: uint,
        occupied: bool,
        vehicle-id: (optional (string-utf8 32)),
        expiry-block: uint
    }
)

(define-map waste-bins
    uint
    {
        bin-id: uint,
        fill-level: uint,
        last-collection: uint,
        needs-service: bool
    }
)

(define-map energy-consumption
    {resource-id: uint, user: principal}
    {
        allocated: uint,
        used: uint,
        last-update: uint
    }
)

(define-map iot-devices
    principal
    {
        device-id: (string-utf8 32),
        device-type: uint,
        resource-id: uint,
        active: bool,
        last-ping: uint,
        authorized: bool
    }
)

;; Validation Functions
(define-private (validate-location (location (string-utf8 64)))
    (> (len location) u0))

(define-private (validate-capacity (capacity uint))
    (and (> capacity u0) (<= capacity MAX-CAPACITY)))

(define-private (validate-price (price uint))
    (and (> price u0) (<= price MAX-PRICE)))

(define-private (validate-vehicle-id (vehicle-id (string-utf8 32)))
    (> (len vehicle-id) u0))

(define-private (validate-device-id (device-id (string-utf8 32)))
    (> (len device-id) u0))

;; Authorization
(define-private (is-admin)
    (is-eq tx-sender (var-get admin)))

(define-private (is-authorized-device)
    (match (map-get? iot-devices tx-sender)
        device (get authorized device)
        false))

;; Resource Management Functions
(define-public (register-resource 
    (resource-type uint)
    (location (string-utf8 64))
    (capacity uint)
    (price uint))
    (begin
        (asserts! (is-admin) ERR-NOT-AUTHORIZED)
        (asserts! (validate-location location) ERR-INVALID-LOCATION)
        (asserts! (validate-capacity capacity) ERR-INVALID-CAPACITY)
        (asserts! (validate-price price) ERR-INVALID-PRICE)
        (asserts! (or 
            (is-eq resource-type RESOURCE-TYPE-PARKING)
            (is-eq resource-type RESOURCE-TYPE-WASTE)
            (is-eq resource-type RESOURCE-TYPE-ENERGY))
            ERR-INVALID-RESOURCE)
        
        (let ((resource-id (var-get resource-count)))
            (map-set resources resource-id
                {
                    resource-type: resource-type,
                    location: location,
                    capacity: capacity,
                    available: capacity,
                    active: true,
                    price: price
                })
            (var-set resource-count (+ resource-id u1))
            (ok resource-id))))

;; Parking Management
(define-public (reserve-parking 
    (resource-id uint)
    (vehicle-id (string-utf8 32))
    (duration uint))
    (let (
        (resource (unwrap! (map-get? resources resource-id) ERR-INVALID-RESOURCE))
        (parking-fee (* (get price resource) duration))
        )
        (asserts! (validate-vehicle-id vehicle-id) ERR-INVALID-VEHICLE)
        (asserts! (>= (get available resource) u1) ERR-RESOURCE-UNAVAILABLE)
        (asserts! (>= parking-fee (var-get min-parking-fee)) ERR-INSUFFICIENT-PAYMENT)
        
        ;; Process payment
        (try! (stx-transfer? parking-fee tx-sender (var-get admin)))
        
        ;; Update parking spot
        (map-set parking-spots resource-id
            {
                spot-id: resource-id,
                occupied: true,
                vehicle-id: (some vehicle-id),
                expiry-block: (+ block-height duration)
            })
        
        ;; Update resource availability
        (map-set resources resource-id
            (merge resource {available: (- (get available resource) u1)}))
        
        (ok true)))

;; Waste Management
(define-public (update-waste-level
    (resource-id uint)
    (fill-level uint))
    (begin
        (asserts! (is-authorized-device) ERR-NOT-AUTHORIZED)
        (asserts! (<= fill-level u100) ERR-INVALID-PARAMS)
        (asserts! (is-some (map-get? resources resource-id)) ERR-INVALID-RESOURCE)
        
        (match (map-get? waste-bins resource-id)
            bin (begin
                (map-set waste-bins resource-id
                    (merge bin {
                        fill-level: fill-level,
                        needs-service: (> fill-level u80),
                        last-collection: block-height
                    }))
                (ok true))
            ERR-INVALID-RESOURCE)))

;; Energy Management
(define-public (allocate-energy
    (resource-id uint)
    (amount uint))
    (let (
        (resource (unwrap! (map-get? resources resource-id) ERR-INVALID-RESOURCE))
        (energy-cost (* amount (var-get energy-rate)))
        )
        (asserts! (validate-capacity amount) ERR-INVALID-CAPACITY)
        (asserts! (>= (get available resource) amount) ERR-RESOURCE-UNAVAILABLE)
        
        ;; Process payment
        (try! (stx-transfer? energy-cost tx-sender (var-get admin)))
        
        ;; Update energy allocation
        (map-set energy-consumption
            {resource-id: resource-id, user: tx-sender}
            {
                allocated: amount,
                used: u0,
                last-update: block-height
            })
        
        (map-set resources resource-id
            (merge resource {available: (- (get available resource) amount)}))
        
        (ok true)))

;; IoT Device Management
(define-public (register-iot-device
    (device-id (string-utf8 32))
    (device-type uint)
    (resource-id uint))
    (begin
        (asserts! (is-admin) ERR-NOT-AUTHORIZED)
        (asserts! (validate-device-id device-id) ERR-INVALID-DEVICE)
        (asserts! (is-some (map-get? resources resource-id)) ERR-INVALID-RESOURCE)
        (asserts! (or 
            (is-eq device-type RESOURCE-TYPE-PARKING)
            (is-eq device-type RESOURCE-TYPE-WASTE)
            (is-eq device-type RESOURCE-TYPE-ENERGY))
            ERR-INVALID-RESOURCE)
        
        (map-set iot-devices tx-sender
            {
                device-id: device-id,
                device-type: device-type,
                resource-id: resource-id,
                active: true,
                last-ping: block-height,
                authorized: true
            })
        (ok true)))

(define-public (deactivate-iot-device (device-principal principal))
    (begin
        (asserts! (is-admin) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (map-get? iot-devices device-principal)) ERR-DEVICE-NOT-FOUND)
        
        (match (map-get? iot-devices device-principal)
            device (begin
                (map-set iot-devices device-principal
                    (merge device {active: false, authorized: false}))
                (ok true))
            ERR-DEVICE-NOT-FOUND)))

(define-public (update-device-ping)
    (match (map-get? iot-devices tx-sender)
        device (begin
            (map-set iot-devices tx-sender
                (merge device {last-ping: block-height}))
            (ok true))
        ERR-DEVICE-NOT-FOUND))

;; Read-only functions
(define-read-only (get-resource-details (resource-id uint))
    (map-get? resources resource-id))

(define-read-only (get-parking-status (resource-id uint))
    (map-get? parking-spots resource-id))

(define-read-only (get-waste-bin-status (resource-id uint))
    (map-get? waste-bins resource-id))

(define-read-only (get-energy-usage (resource-id uint) (user principal))
    (map-get? energy-consumption {resource-id: resource-id, user: user}))

(define-read-only (get-device-status (device-principal principal))
    (map-get? iot-devices device-principal))