
;; title: HedgeVault
;; version: 1.0.0
;; summary: DeFi lending protocol with integrated risk hedging and derivative protection
;; description: HedgeVault allows users to lend and borrow STX with automated risk management,
;;              collateral hedging, and derivative-based downside protection

;; traits
;; (use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; token definitions
(define-fungible-token hvault-token)

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-LOAN-NOT-FOUND (err u104))
(define-constant ERR-LOAN-ALREADY-LIQUIDATED (err u105))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u106))
(define-constant ERR-LIQUIDATION-NOT-ALLOWED (err u107))
(define-constant ERR-HEDGE-EXPIRED (err u108))
(define-constant ERR-INVALID-HEDGE-PARAMS (err u109))

;; Minimum collateralization ratio (150%)
(define-constant MIN-COLLATERAL-RATIO u150)
;; Liquidation threshold (120%)
(define-constant LIQUIDATION-THRESHOLD u120)
;; Maximum loan-to-value ratio (80%)
(define-constant MAX-LTV u80)
;; Base interest rate (5% annual)
(define-constant BASE-INTEREST-RATE u5)
;; Hedge fee (1%)
(define-constant HEDGE-FEE u1)

;; data vars
(define-data-var total-supply-stx uint u0)
(define-data-var total-borrowed-stx uint u0)
(define-data-var protocol-fee uint u2) ;; 2%
(define-data-var emergency-pause bool false)
(define-data-var loan-counter uint u0)
(define-data-var hedge-counter uint u0)

;; data maps
(define-map user-deposits principal uint)
(define-map user-borrowed principal uint)
(define-map user-collateral principal uint)
(define-map hvault-balances principal uint)

(define-map loans 
  uint 
  {
    borrower: principal,
    amount: uint,
    collateral: uint,
    interest-rate: uint,
    start-block: uint,
    last-update: uint,
    liquidated: bool
  })

(define-map hedges
  uint
  {
    user: principal,
    loan-id: uint,
    hedge-amount: uint,
    strike-price: uint,
    expiry-block: uint,
    premium-paid: uint,
    active: bool
  })

(define-map oracle-prices principal uint) ;; Simple price oracle simulation

;; public functions

;; Initialize the contract (called once by deployer)
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    ;; Set initial STX price (example: $30 with 6 decimals)
    (map-set oracle-prices tx-sender u30000000)
    (ok true)))

;; Deposit STX to earn yield
(define-public (deposit (amount uint))
  (let ((sender tx-sender))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (not (var-get emergency-pause)) ERR-NOT-AUTHORIZED)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    
    ;; Update user deposit balance
    (map-set user-deposits sender 
      (+ (default-to u0 (map-get? user-deposits sender)) amount))
    
    ;; Update total supply
    (var-set total-supply-stx (+ (var-get total-supply-stx) amount))
    
    ;; Mint hvault tokens (1:1 ratio for simplicity)
    (try! (ft-mint? hvault-token amount sender))
    (map-set hvault-balances sender 
      (+ (default-to u0 (map-get? hvault-balances sender)) amount))
    
    (ok amount)))

;; Withdraw deposited STX plus earned interest
(define-public (withdraw (hvault-amount uint))
  (let ((sender tx-sender)
        (user-hvault-balance (default-to u0 (map-get? hvault-balances sender))))
    (asserts! (> hvault-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= hvault-amount user-hvault-balance) ERR-INSUFFICIENT-FUNDS)
    (asserts! (not (var-get emergency-pause)) ERR-NOT-AUTHORIZED)
    
    ;; Calculate STX amount to withdraw (accounting for interest earned)
    (let ((stx-amount (calculate-withdrawal-amount hvault-amount)))
      (asserts! (<= stx-amount (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-FUNDS)
      
      ;; Burn hvault tokens
      (try! (ft-burn? hvault-token hvault-amount sender))
      (map-set hvault-balances sender (- user-hvault-balance hvault-amount))
      
      ;; Transfer STX to user
      (try! (as-contract (stx-transfer? stx-amount tx-sender sender)))
      
      ;; Update total supply
      (var-set total-supply-stx (- (var-get total-supply-stx) stx-amount))
      
      (ok stx-amount))))

;; Create a collateralized loan
(define-public (create-loan (loan-amount uint) (collateral-amount uint))
  (let ((sender tx-sender)
        (loan-id (+ (var-get loan-counter) u1))
        (current-block block-height))
    (asserts! (> loan-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> collateral-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (not (var-get emergency-pause)) ERR-NOT-AUTHORIZED)
    
    ;; Check collateralization ratio
    (asserts! (>= (* collateral-amount u100) (* loan-amount MIN-COLLATERAL-RATIO)) 
              ERR-INSUFFICIENT-COLLATERAL)
    
    ;; Check if protocol has enough liquidity
    (asserts! (<= loan-amount (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer collateral from user to contract
    (try! (stx-transfer? collateral-amount sender (as-contract tx-sender)))
    
    ;; Create loan record
    (map-set loans loan-id {
      borrower: sender,
      amount: loan-amount,
      collateral: collateral-amount,
      interest-rate: BASE-INTEREST-RATE,
      start-block: current-block,
      last-update: current-block,
      liquidated: false
    })
    
    ;; Transfer loan amount to borrower
    (try! (as-contract (stx-transfer? loan-amount tx-sender sender)))
    
    ;; Update tracking variables
    (var-set loan-counter loan-id)
    (var-set total-borrowed-stx (+ (var-get total-borrowed-stx) loan-amount))
    (map-set user-borrowed sender 
      (+ (default-to u0 (map-get? user-borrowed sender)) loan-amount))
    (map-set user-collateral sender 
      (+ (default-to u0 (map-get? user-collateral sender)) collateral-amount))
    
    (ok loan-id)))

;; Repay loan
(define-public (repay-loan (loan-id uint))
  (let ((loan-data (unwrap! (map-get? loans loan-id) ERR-LOAN-NOT-FOUND))
        (sender tx-sender))
    (asserts! (is-eq sender (get borrower loan-data)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get liquidated loan-data)) ERR-LOAN-ALREADY-LIQUIDATED)
    
    ;; Calculate total amount to repay (principal + interest)
    (let ((total-repay-amount (calculate-repay-amount loan-id)))
      (asserts! (>= (stx-get-balance sender) total-repay-amount) ERR-INSUFFICIENT-FUNDS)
      
      ;; Transfer repayment from borrower to contract
      (try! (stx-transfer? total-repay-amount sender (as-contract tx-sender)))
      
      ;; Return collateral to borrower
      (try! (as-contract (stx-transfer? (get collateral loan-data) tx-sender sender)))
      
      ;; Update loan status (mark as repaid by setting amount to 0)
      (map-set loans loan-id (merge loan-data {amount: u0}))
      
      ;; Update tracking variables
      (var-set total-borrowed-stx (- (var-get total-borrowed-stx) (get amount loan-data)))
      (map-set user-borrowed sender 
        (- (default-to u0 (map-get? user-borrowed sender)) (get amount loan-data)))
      (map-set user-collateral sender 
        (- (default-to u0 (map-get? user-collateral sender)) (get collateral loan-data)))
      
      (ok total-repay-amount))))

;; Create a hedge position to protect against downside risk
(define-public (create-hedge (loan-id uint) (hedge-amount uint) (strike-price uint) (duration-blocks uint))
  (let ((loan-data (unwrap! (map-get? loans loan-id) ERR-LOAN-NOT-FOUND))
        (sender tx-sender)
        (hedge-id (+ (var-get hedge-counter) u1))
        (premium (calculate-hedge-premium hedge-amount duration-blocks)))
    (asserts! (is-eq sender (get borrower loan-data)) ERR-NOT-AUTHORIZED)
    (asserts! (> hedge-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> strike-price u0) ERR-INVALID-HEDGE-PARAMS)
    (asserts! (> duration-blocks u0) ERR-INVALID-HEDGE-PARAMS)
    (asserts! (<= hedge-amount (get collateral loan-data)) ERR-INVALID-HEDGE-PARAMS)
    
    ;; User pays premium for hedge
    (try! (stx-transfer? premium sender (as-contract tx-sender)))
    
    ;; Create hedge record
    (map-set hedges hedge-id {
      user: sender,
      loan-id: loan-id,
      hedge-amount: hedge-amount,
      strike-price: strike-price,
      expiry-block: (+ block-height duration-blocks),
      premium-paid: premium,
      active: true
    })
    
    (var-set hedge-counter hedge-id)
    (ok hedge-id)))

;; Exercise hedge if conditions are met
(define-public (exercise-hedge (hedge-id uint))
  (let ((hedge-data (unwrap! (map-get? hedges hedge-id) ERR-LOAN-NOT-FOUND))
        (sender tx-sender)
        (current-price (default-to u30000000 (map-get? oracle-prices tx-sender))))
    (asserts! (is-eq sender (get user hedge-data)) ERR-NOT-AUTHORIZED)
    (asserts! (get active hedge-data) ERR-HEDGE-EXPIRED)
    (asserts! (<= block-height (get expiry-block hedge-data)) ERR-HEDGE-EXPIRED)
    
    ;; Check if hedge is in the money (current price < strike price)
    (asserts! (< current-price (get strike-price hedge-data)) ERR-LIQUIDATION-NOT-ALLOWED)
    
    ;; Calculate payout
    (let ((payout (calculate-hedge-payout hedge-id current-price)))
      ;; Transfer payout to user
      (try! (as-contract (stx-transfer? payout tx-sender sender)))
      
      ;; Mark hedge as exercised (inactive)
      (map-set hedges hedge-id (merge hedge-data {active: false}))
      
      (ok payout))))

;; Liquidate undercollateralized loans
(define-public (liquidate-loan (loan-id uint))
  (let ((loan-data (unwrap! (map-get? loans loan-id) ERR-LOAN-NOT-FOUND))
        (current-price (default-to u30000000 (map-get? oracle-prices tx-sender))))
    (asserts! (not (get liquidated loan-data)) ERR-LOAN-ALREADY-LIQUIDATED)
    
    ;; Check if loan is undercollateralized
    (let ((collateral-value (* (get collateral loan-data) current-price))
          (debt-value (* (calculate-repay-amount loan-id) current-price)))
      (asserts! (< (* collateral-value u100) (* debt-value LIQUIDATION-THRESHOLD)) 
                ERR-LIQUIDATION-NOT-ALLOWED)
      
      ;; Mark loan as liquidated
      (map-set loans loan-id (merge loan-data {liquidated: true}))
      
      ;; Transfer collateral to liquidator (with liquidation bonus)
      (let ((liquidation-bonus (/ (get collateral loan-data) u20))) ;; 5% bonus
        (try! (as-contract (stx-transfer? (+ (get collateral loan-data) liquidation-bonus) 
                                          tx-sender tx-sender)))
        
        ;; Update tracking variables
        (var-set total-borrowed-stx (- (var-get total-borrowed-stx) (get amount loan-data)))
        
        (ok true)))))

;; Emergency functions
(define-public (set-emergency-pause (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set emergency-pause paused)
    (ok paused)))

;; Update oracle price (in production this would be automated)
(define-public (update-price (asset principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (map-set oracle-prices asset price)
    (ok true)))

;; read only functions

(define-read-only (get-user-deposit (user principal))
  (default-to u0 (map-get? user-deposits user)))

(define-read-only (get-user-borrowed (user principal))
  (default-to u0 (map-get? user-borrowed user)))

(define-read-only (get-user-collateral (user principal))
  (default-to u0 (map-get? user-collateral user)))

(define-read-only (get-hvault-balance (user principal))
  (default-to u0 (map-get? hvault-balances user)))

(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id))

(define-read-only (get-hedge (hedge-id uint))
  (map-get? hedges hedge-id))

(define-read-only (get-protocol-stats)
  {
    total-supply: (var-get total-supply-stx),
    total-borrowed: (var-get total-borrowed-stx),
    utilization-rate: (if (> (var-get total-supply-stx) u0)
                        (/ (* (var-get total-borrowed-stx) u100) (var-get total-supply-stx))
                        u0),
    loan-counter: (var-get loan-counter),
    hedge-counter: (var-get hedge-counter)
  })

(define-read-only (get-asset-price (asset principal))
  (default-to u0 (map-get? oracle-prices asset)))

;; private functions

(define-private (calculate-withdrawal-amount (hvault-amount uint))
  ;; Simple 1:1 conversion for now, in production would include earned interest
  hvault-amount)

(define-private (calculate-repay-amount (loan-id uint))
  (let ((loan-data (unwrap-panic (map-get? loans loan-id))))
    ;; Simple interest calculation: principal + (principal * rate * blocks / blocks-per-year)
    ;; Assuming ~52,560 blocks per year (10 minute blocks)
    (let ((principal (get amount loan-data))
          (blocks-elapsed (- block-height (get start-block loan-data)))
          (interest (* (* principal (get interest-rate loan-data)) 
                      (/ blocks-elapsed u52560))))
      (+ principal (/ interest u100)))))

(define-private (calculate-hedge-premium (amount uint) (duration uint))
  ;; Simple premium calculation: amount * hedge-fee% * duration-factor
  (let ((base-premium (/ (* amount HEDGE-FEE) u100))
        (duration-factor (if (> duration u1000) u2 u1)))
    (* base-premium duration-factor)))

(define-private (calculate-hedge-payout (hedge-id uint) (current-price uint))
  (let ((hedge-data (unwrap-panic (map-get? hedges hedge-id))))
    ;; Payout = hedge-amount * (strike-price - current-price) / strike-price
    (let ((price-diff (- (get strike-price hedge-data) current-price)))
      (/ (* (get hedge-amount hedge-data) price-diff) (get strike-price hedge-data)))))
