;; TrackLedger - Supply Chain Tracking Contract
(define-data-var last-item-id uint u0)
(define-data-var last-batch-id uint u0)

;; Define item status values
(define-constant STATUS-CREATED u1)
(define-constant STATUS-IN-TRANSIT u2)
(define-constant STATUS-DELIVERED u3)

;; Error codes
(define-constant err-not-found (err u404))
(define-constant err-unauthorized (err u401))
(define-constant err-invalid-status (err u400))
(define-constant err-empty-batch (err u402))

;; Item structure
(define-map items
    {item-id: uint}
    {
        owner: principal,
        manufacturer: principal,
        status: uint,
        metadata: (string-utf8 256),
        created-at: uint,
        batch-id: (optional uint)
    }
)

;; Batch structure
(define-map batches
    {batch-id: uint}
    {
        owner: principal,
        items: (list 50 uint),
        created-at: uint
    }
)

;; Event history
(define-map item-events
    {item-id: uint, event-id: uint}
    {
        timestamp: uint,
        event-type: (string-utf8 64),
        data: (string-utf8 256),
        recorder: principal
    }
)

(define-data-var last-event-id uint u0)

;; Create new item
(define-public (create-item (metadata (string-utf8 256)))
    (let
        ((new-item-id (+ (var-get last-item-id) u1)))
        (begin
            (map-set items
                {item-id: new-item-id}
                {
                    owner: tx-sender,
                    manufacturer: tx-sender,
                    status: STATUS-CREATED,
                    metadata: metadata,
                    created-at: block-height,
                    batch-id: none
                }
            )
            (var-set last-item-id new-item-id)
            (record-event new-item-id "CREATED" metadata)
            (ok new-item-id)
        )
    )
)

;; Create new batch of items
(define-public (create-batch (item-ids (list 50 uint)))
    (let 
        ((new-batch-id (+ (var-get last-batch-id) u1)))
        (if (> (len item-ids) u0)
            (begin
                (map-set batches
                    {batch-id: new-batch-id}
                    {
                        owner: tx-sender,
                        items: item-ids,
                        created-at: block-height
                    }
                )
                (var-set last-batch-id new-batch-id)
                ;; Update batch-id for all items
                (map update-item-batch-id (map to-uint item-ids))
                (ok new-batch-id)
            )
            err-empty-batch
        )
    )
)

;; Helper to update item batch-id
(define-private (update-item-batch-id (item-id uint))
    (let ((item (unwrap! (get-item item-id) false)))
        (map-set items
            {item-id: item-id}
            (merge item {batch-id: (some (var-get last-batch-id))})
        )
    )
)

;; Transfer ownership
(define-public (transfer-ownership (item-id uint) (new-owner principal))
    (let ((item (unwrap! (get-item item-id) err-not-found)))
        (if (is-eq (get owner item) tx-sender)
            (begin
                (map-set items
                    {item-id: item-id}
                    (merge item {owner: new-owner})
                )
                (record-event item-id "TRANSFER" (concat "New owner: " (to-ascii new-owner)))
                (ok true)
            )
            err-unauthorized
        )
    )
)

;; Update item status
(define-public (update-status (item-id uint) (new-status uint))
    (let ((item (unwrap! (get-item item-id) err-not-found)))
        (if (and
                (is-eq (get owner item) tx-sender)
                (or (is-eq new-status STATUS-IN-TRANSIT)
                    (is-eq new-status STATUS-DELIVERED))
            )
            (begin
                (map-set items
                    {item-id: item-id}
                    (merge item {status: new-status})
                )
                (record-event item-id "STATUS_UPDATE" (concat "New status: " (to-ascii new-status)))
                (ok true)
            )
            err-invalid-status
        )
    )
)

;; Record an event
(define-private (record-event (item-id uint) (event-type (string-utf8 64)) (data (string-utf8 256)))
    (let
        ((new-event-id (+ (var-get last-event-id) u1)))
        (begin
            (map-set item-events
                {item-id: item-id, event-id: new-event-id}
                {
                    timestamp: block-height,
                    event-type: event-type,
                    data: data,
                    recorder: tx-sender
                }
            )
            (var-set last-event-id new-event-id)
            (ok new-event-id)
        )
    )
)

;; Getter for item details
(define-read-only (get-item (item-id uint))
    (map-get? items {item-id: item-id})
)

;; Get batch details
(define-read-only (get-batch (batch-id uint))
    (map-get? batches {batch-id: batch-id})
)

;; Get event details
(define-read-only (get-event (item-id uint) (event-id uint))
    (map-get? item-events {item-id: item-id, event-id: event-id})
)

;; Verify item authenticity
(define-read-only (verify-item (item-id uint))
    (let ((item (map-get? items {item-id: item-id})))
        (if (is-some item)
            (ok {
                authentic: true,
                manufacturer: (get manufacturer (unwrap-panic item)),
                current-owner: (get owner (unwrap-panic item))
            })
            err-not-found
        )
    )
)
