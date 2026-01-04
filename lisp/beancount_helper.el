;;; beancount_helper.el --- Consult-based Beancount Transaction Entry -*- lexical-binding: t; -*-

;;; Commentary:
;; Streamlined beancount transaction entry using consult prompts

;;; Code:

(require 'cl-lib)

;;; Last Transaction Tracking (for rts-flow-clock-goto integration)
(defvar beancount-helper-last-marker nil
  "Marker to the last transaction inserted.")

(defvar beancount-helper-last-description nil
  "Description of the last transaction inserted.")

;; Only require these if available
(require 'consult nil t)
(require 'beancount nil t)

(defvar beancount-helper-file "/Users/alokregmi/scratch/scripts/personal.beancount"
  "Path to the main beancount file to read from and write to.")

(defvar beancount-helper-default-currency "NPR"
  "Default currency for transactions.")

(defvar beancount-helper-common-payees
  '("Bhatbhateni" "Salesberry" "BigMart" "Foodmandu" "Pathao" "InDrive" 
    "Daraz" "Gyapu" "CG Digital" "Ncell" "NTC" "WorldLink" "Subisu"
    "KFC" "Pizza Hut" "Burger House" "Cafe" "Restaurant" "Pharmacy"
    "Hospital" "Clinic" "Lab" "Uber" "Sajilo Marmat" "Electricity" "Water")
  "Common payees for quick selection.")

(defvar beancount-helper-persons
  '("MY" "MOM" "DAD" "SUS" "SAJ")
  "Family members for investment accounts.")

(defvar beancount-helper-stock-types
  '("Regular" "IPO" "FPO")
  "Types of stock purchases.")

(defvar beancount-helper-section-markers
  '((expenses . "^\\* Expenses")
    (income . "^\\* Taxable Investments")
    (investments . "^\\* Taxable Investments")
    (banking . "^\\* Banking")
    (cash . "^\\* Cash")
    (credit-cards . "^\\* Credit-Cards"))
  "Regex patterns to find section markers in the beancount file.")

(defun beancount-helper--get-all-accounts ()
  "Get all accounts from the beancount file."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (let ((accounts '()))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "^[0-9-]+ open \\([A-Za-z:]+\\)" nil t)
          (push (match-string 1) accounts)))
      (nreverse accounts))))

(defun beancount-helper--account-exists-p (account)
  "Check if ACCOUNT exists in the beancount file."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (save-excursion
      (goto-char (point-min))
      (re-search-forward (format "^[0-9-]+ open %s" (regexp-quote account)) nil t))))

(defun beancount-helper--get-section-name (account)
  "Get the appropriate section name for ACCOUNT."
  (let* ((account-type (car (split-string account ":")))
         (account-parts (split-string account ":")))
    (cond
     ((string= account-type "Expenses") "Expenses")
     ((string= account-type "Income") "Taxable Investments")
     ((string= account-type "Assets")
      (cond
       ;; ETrade accounts go to Taxable Investments
       ((and (>= (length account-parts) 3)
             (string= (nth 2 account-parts) "ETrade"))
        "Taxable Investments")
       ;; Cash/Esewa/Khalti go to Cash section
       ((string-match-p "Cash\\|Esewa\\|Khalti" account) "Cash")
       ;; Default assets go to Banking
       (t "Banking")))
     ((string= account-type "Liabilities") "Credit-Cards")
     (t "Banking"))))

(defun beancount-helper--find-section-bounds (section-name)
  "Find the start and end positions of SECTION-NAME in the beancount file.
Returns (START . END) where START is after the section header
and END is before the next section or EOF."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward (format "^\\* %s" (regexp-quote section-name)) nil t)
        (let ((section-start (progn (forward-line 1) (point)))
              (section-end (if (re-search-forward "^\\* " nil t)
                               (progn (beginning-of-line) (point))
                             (point-max))))
          (cons section-start section-end))))))

(defun beancount-helper--create-account (account)
  "Create a new ACCOUNT in the appropriate section."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (let* ((section-name (beancount-helper--get-section-name account))
           (bounds (beancount-helper--find-section-bounds section-name)))
      (if bounds
          (save-excursion
            ;; Go to start of section (right after header)
            (goto-char (car bounds))
            ;; Skip any existing blank lines
            (while (and (looking-at "^\\s-*$") 
                        (< (point) (cdr bounds)))
              (forward-line 1))
            ;; Insert the new account
            (insert (format "%s open %s\n" (format-time-string "%Y-%m-%d") account))
            (save-buffer)
            (message "Created account: %s in section %s" account section-name))
        ;; Section doesn't exist - create it
        (save-excursion
          (goto-char (point-max))
          (insert (format "\n* %s\n\n%s open %s\n" 
                          section-name
                          (format-time-string "%Y-%m-%d")
                          account))
          (save-buffer)
          (message "Created section %s and account: %s" section-name account))))))

(defun beancount-helper--get-payees ()
  "Get all unique payees from the beancount file."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (let ((payees beancount-helper-common-payees))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "^[0-9-]+ \\*\\(\\|!\\) \"\\([^\"]+\\)\"" nil t)
          (let ((payee (match-string 2)))
            (unless (member payee payees)
              (push payee payees)))))
      payees)))

(defun beancount-helper--find-insertion-point (date &optional section-name)
  "Find the appropriate insertion point for a transaction with DATE.
Optional SECTION-NAME to specify which section to insert into."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (let* ((section (or section-name "Taxable Investments"))
           (bounds (beancount-helper--find-section-bounds section)))
      (if bounds
          (save-excursion
            (goto-char (cdr bounds))
            (skip-chars-backward " \t\n")
            (unless (bolp) (forward-line 1))
            (point))
        ;; Fallback to end of file
        (save-excursion
          (goto-char (point-max))
          (skip-chars-backward " \t\n")
          (unless (bolp) (forward-line 1))
          (point))))))

(defun beancount-helper--insert-transaction (transaction date &optional section-name description)
  "Insert TRANSACTION at the appropriate point for DATE in the file.
Optional SECTION-NAME to specify which section to insert into.
Optional DESCRIPTION for tracking purposes (used by rts-flow-clock-goto)."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (goto-char (beancount-helper--find-insertion-point date section-name))
    (let ((insert-point (point)))
      (insert "\n" transaction)
      ;; Remember this transaction for rts-flow-clock-goto
      (setq beancount-helper-last-marker (copy-marker insert-point)
            beancount-helper-last-description (or description
                                                   (when (string-match "\\* \"\\([^\"]+\\)\"" transaction)
                                                     (match-string 1 transaction))
                                                   "Beancount transaction"))
      (save-buffer))))

(defun beancount-helper--create-commodity (ticker)
  "Create a commodity for TICKER if needed."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (unless (save-excursion
              (goto-char (point-min))
              (re-search-forward (format "^[0-9-]+ commodity %s" ticker) nil t))
      (when (y-or-n-p (format "Create commodity %s? " ticker))
        (let ((bounds (beancount-helper--find-section-bounds "Commodities")))
          (if bounds
              (save-excursion
                (goto-char (car bounds))
                ;; Skip existing commodities to add at end of section content
                (while (and (not (looking-at "^\\s-*$\\|^\\*"))
                            (< (point) (cdr bounds)))
                  (forward-line 1))
                (insert (format "\n%s commodity %s\n  name: \"%s Stock\"\n" 
                                (format-time-string "%Y-%m-%d") ticker ticker))
                (save-buffer))
            ;; Create Commodities section if missing
            (save-excursion
              (goto-char (point-min))
              (if (re-search-forward "^\\* Options" nil t)
                  (progn
                    (if (re-search-forward "^\\* " nil t)
                        (beginning-of-line)
                      (goto-char (point-max)))
                    (insert (format "\n* Commodities\n\n%s commodity %s\n  name: \"%s Stock\"\n"
                                    (format-time-string "%Y-%m-%d") ticker ticker)))
                ;; Fallback
                (goto-char (point-min))
                (insert (format "* Commodities\n\n%s commodity %s\n  name: \"%s Stock\"\n\n"
                                (format-time-string "%Y-%m-%d") ticker ticker)))
              (save-buffer))))))))

(defun beancount-helper--format-amount (amount currency)
  "Format AMOUNT with CURRENCY, handling negative values."
  (if (string-match "^-" amount)
      (format "%s %s" amount currency)
    (format "%s %s" amount currency)))

;;;###autoload
(defun beancount-helper-add-transaction ()
  "Add a new transaction with consult prompts."
  (interactive)
  (let* ((date (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d")))
         (payee (completing-read "Payee: " (beancount-helper--get-payees) nil nil))
         (description (read-string "Description (optional): " ""))
         (all-accounts (beancount-helper--get-all-accounts))
         (from-account (completing-read "From account: " all-accounts nil nil))
         (to-account (completing-read "To account: " all-accounts nil nil))
         (amount (read-string "Amount: "))
         (currency (completing-read "Currency: " '("NPR" "USD") nil nil beancount-helper-default-currency)))
            
    ;; Create accounts if they don't exist
    (unless (beancount-helper--account-exists-p from-account)
      (when (y-or-n-p (format "Account %s doesn't exist. Create it? " from-account))
        (beancount-helper--create-account from-account)))
            
    (unless (beancount-helper--account-exists-p to-account)
      (when (y-or-n-p (format "Account %s doesn't exist. Create it? " to-account))
        (beancount-helper--create-account to-account)))
            
    ;; Build transaction string
    (let ((transaction (format "%s * \"%s\"%s\n  %s  %s\n  %s  %s\n"
                               date
                               payee
                               (if (equal description "") "" (format " \"%s\"" description))
                               from-account
                               (beancount-helper--format-amount (format "-%s" amount) currency)
                               to-account
                               (beancount-helper--format-amount amount currency))))
              
      ;; Insert at appropriate position in the file
      (beancount-helper--insert-transaction transaction date)
      (message "Transaction added successfully!"))))

(defun beancount-helper--get-person-accounts ()
  "Get all person expense accounts from the file."
  (with-current-buffer (find-file-noselect beancount-helper-file)
    (let ((persons '()))
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward "^[0-9-]+ open Expenses:Person:\\([A-Za-z]+\\)" nil t)
          (push (match-string 1) persons)))
      (nreverse persons))))

(defun beancount-helper--create-person-account (person)
  "Create a person expense account for PERSON."
  (let ((account (format "Expenses:Person:%s" person)))
    (unless (beancount-helper--account-exists-p account)
      (beancount-helper--create-account account))))

;;;###autoload
(defun beancount-helper-add-expense ()
  "Quick expense entry with optional split functionality."
  (interactive)
  (let* ((date (format-time-string "%Y-%m-%d"))
         (total-amount (string-to-number (read-string "Amount spent: ")))
         (payee (completing-read "Payee/Store: " (beancount-helper--get-payees) nil nil))
         (description (read-string "Description (optional): " ""))
         (expense-categories '("Expenses:Food:Outdoors"
                               "Expenses:Food:Groceries"
                               "Expenses:Food:Gatherings"
                               "Expenses:Travel"
                               "Expenses:Home:Internet"
                               "Expenses:Home:Mobile"
                               "Expenses:Ownership:Clothing"
                               "Expenses:Ownership:Electronics"
                               "Expenses:Medicine"
                               "Expenses:RandomFun"
                               "Expenses:HouseCommon"))
         (expense-account (completing-read "Expense type: " expense-categories nil nil))
         (payment-accounts '("Assets:NP:MY:Cash"
                             "Assets:NP:MY:Esewa"
                             "Assets:NP:MY:Khalti"
                             "Assets:NP:MY:RBBChecking"
                             "Assets:NP:MY:SBLChecking"
                             "Liabilities:NP:SBL"))
         (from-account (completing-read "Paid with: " payment-accounts nil nil))
         (split-p (y-or-n-p "Split this expense? ")))
    
    (if (not split-p)
        ;; Regular expense without split
        (let ((transaction (format "%s * \"%s\"%s\n  %s  -%s NPR\n  %s  %s NPR\n"
                                   date
                                   payee
                                   (if (equal description "") "" (format " \"%s\"" description))
                                   from-account
                                   (format "%.2f" total-amount)
                                   expense-account
                                   (format "%.2f" total-amount))))
          (beancount-helper--insert-transaction transaction date "Expenses")
          (message "Expense added: %.2f NPR at %s" total-amount payee))
      
      ;; Split expense among people
      (let* ((existing-persons (beancount-helper--get-person-accounts))
             (all-persons (append existing-persons 
                                   '("Family" "Sajja" "Sushma" "Momma" "Dad" 
                                     "Aashish" "Shambhu" "Aatish" "Shishir")))
             ;; Use completing-read-multiple for comma-separated selection
             (selected-persons (completing-read-multiple
                               "Select people to split with (comma-separated): "
                               all-persons nil nil)))
        
        ;; Create person accounts for new people
        (dolist (person selected-persons)
          (unless (member person existing-persons)
            (when (y-or-n-p (format "Create new person account for %s? " person))
              (beancount-helper--create-person-account person))))
        
        (if (null selected-persons)
            (message "No people selected for split. Cancelling.")
          ;; Calculate split
          (let* ((num-people (1+ (length selected-persons))) ; +1 for yourself
                 (share-amount (/ total-amount num-people))
                 (my-share share-amount)
                 (transaction-lines (list (format "%s * \"%s\"%s"
                                                  date payee
                                                  (if (equal description "") 
                                                      " \"Split expense\""
                                                    (format " \"%s (split)\"" description))))))
            
            ;; Payment line
            (push (format "  %s  -%.2f NPR" from-account total-amount) transaction-lines)
            
            ;; My share of the expense
            (push (format "  %s  %.2f NPR" expense-account my-share) transaction-lines)
            
            ;; Each person owes their share
            (dolist (person selected-persons)
              (push (format "  Expenses:Person:%s  %.2f NPR" person share-amount) transaction-lines))
            
            (let ((transaction (mapconcat 'identity (nreverse transaction-lines) "\n")))
              (beancount-helper--insert-transaction (concat transaction "\n") date "Expenses")
              (message "Split expense: %.2f NPR total, %.2f NPR each among %d people" 
                       total-amount share-amount num-people))))))))

;;;###autoload
(defun beancount-helper-add-income ()
  "Quick income entry."
  (interactive)
  (let* ((date (format-time-string "%Y-%m-%d"))
         (amount (read-string "Income amount: "))
         (source (read-string "Income source: "))
         (income-accounts '("Income:NP:Nepali:Freelancing"
                            "Income:US:Foreign:Freelancing"
                            "Income:NP:Nepali:HouseCommon"))
         (income-account (completing-read "Income type: " income-accounts nil nil))
         (deposit-accounts '("Assets:NP:MY:RBBChecking"
                             "Assets:NP:MY:SBLChecking"
                             "Assets:US:MY:Deel"
                             "Assets:NP:MY:Cash"
                             "Assets:NP:MY:Esewa"))
         (to-account (completing-read "Deposit to: " deposit-accounts nil nil))
         (currency (completing-read "Currency: " '("NPR" "USD") nil nil "NPR")))
            
    (let ((transaction (format "%s * \"%s\"\n  %s  %s %s\n  %s  -%s %s\n"
                               date
                               source
                               to-account
                               amount
                               currency
                               income-account
                               amount
                               currency)))
              
      (beancount-helper--insert-transaction transaction date)
      (message "Income added: %s %s from %s" amount currency source))))

;;;###autoload
(defun beancount-helper-transfer ()
  "Quick transfer between accounts."
  (interactive)
  (let* ((date (format-time-string "%Y-%m-%d"))
         (amount (read-string "Transfer amount: "))
         (all-accounts (beancount-helper--get-all-accounts))
         (from-account (completing-read "Transfer from: " all-accounts nil nil))
         (to-account (completing-read "Transfer to: " all-accounts nil nil))
         (currency (completing-read "Currency: " '("NPR" "USD") nil nil "NPR"))
         (description (read-string "Description (optional): " "Transfer")))
            
    (let ((transaction (format "%s * \"%s\"\n  %s  -%s %s\n  %s  %s %s\n"
                               date
                               description
                               from-account
                               amount
                               currency
                               to-account
                               amount
                               currency)))
              
      (beancount-helper--insert-transaction transaction date)
      (message "Transfer completed: %s %s from %s to %s" amount currency from-account to-account))))

;;;###autoload
(defun beancount-helper-buy-stock ()
  "Buy stock, IPO, or FPO shares with person tracking."
  (interactive)
  (let* ((date (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d")))
         (person (completing-read "Whose account: " beancount-helper-persons nil t nil nil "MY"))
         (stock-type (completing-read "Type: " beancount-helper-stock-types nil t nil nil "Regular"))
         (ticker (upcase (read-string "Stock ticker: ")))
         (shares (read-string "Number of shares: " 
                              (if (string= stock-type "IPO") "10" "")))
         (price (read-string "Price per share: "))
         (currency (or (completing-read "Currency: " '("NPR" "USD") nil t nil nil "NPR") "NPR"))
         (commission (or (read-string "Commission (default 25): " "25") "25"))
         (broker-accounts '("Assets:NP:MY:RBBChecking"
                            "Assets:NP:MY:SBLChecking"
                            "Assets:NP:MY:Cash"
                            "Assets:US:MY:Deel"))
         (cash-account (or (completing-read "Pay from account: " broker-accounts nil t) 
                           (car broker-accounts)))
         (stock-account (if (string= stock-type "Regular")
                            (format "Assets:%s:ETrade:%s:%s" 
                                    (if (string= currency "USD") "US" "NP")
                                    person ticker)
                          (format "Assets:%s:ETrade:%s:%s:%s"
                                  (if (string= currency "USD") "US" "NP")
                                  person stock-type ticker)))
         (commission-account (format "Expenses:%s:Financial:Commissions" person))
         (total (+ (* (string-to-number shares) (string-to-number price))
                   (string-to-number commission))))
            
    ;; Create commodity for the ticker if needed
    (beancount-helper--create-commodity ticker)
    
    ;; Create stock account if needed
    (unless (beancount-helper--account-exists-p stock-account)
      (when (y-or-n-p (format "Account %s doesn't exist. Create it? " stock-account))
        (beancount-helper--create-account stock-account)))
            
    ;; Create commission account if needed
    (unless (beancount-helper--account-exists-p commission-account)
      (when (y-or-n-p (format "Create %s account? " commission-account))
        (beancount-helper--create-account commission-account)))
            
    ;; Validate inputs
    (when (or (equal ticker "")
              (equal shares "")
              (equal price ""))
      (error "Ticker, shares, and price are required"))
            
    (let ((transaction (format "%s * \"Buy %sshares of %s%s\"\n  %s  -%.2f %s\n  %s  %s %s {%s %s, %s}\n  %s  %s %s\n"
                               date 
                               (if (string= stock-type "Regular") "" (concat stock-type " "))
                               ticker
                               (if (string= person "MY") "" (format " for %s" person))
                               cash-account total currency
                               stock-account shares ticker price currency date
                               commission-account commission currency))
          (inhibit-read-only t))
              
      (beancount-helper--insert-transaction transaction date)
      (message "Bought %s shares of %s at %s %s" shares ticker price currency))))

;;;###autoload
(defun beancount-helper-sell-stock ()
  "Sell stock shares with person and type detection."
  (interactive)
  (let* ((date (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d")))
         (ticker (upcase (read-string "Stock ticker to sell: ")))
         ;; Find available lots across all persons
         (lots (beancount-helper--get-stock-lots ticker))
         (lot-strings (mapcar (lambda (lot)
                                (format "%s: %s shares @ %s %s%s (bought %s)"
                                        (nth 0 lot) ; person
                                        (nth 2 lot) ; shares
                                        (nth 3 lot) ; price
                                        (nth 4 lot) ; currency
                                        (if (nth 1 lot) (format " (%s)" (nth 1 lot)) "") ; type
                                        (nth 5 lot))) ; date
                              lots)))
            
    (if (null lots)
        (message "No lots found for %s" ticker)
      (let* ((selected-lot (completing-read "Select lot to sell: " lot-strings nil t))
             (lot-index (cl-position selected-lot lot-strings :test 'string=))
             (lot (nth lot-index lots))
             (person (nth 0 lot))
             (stock-type (nth 1 lot))
             (shares-available (nth 2 lot))
             (cost-price (nth 3 lot))
             (currency (nth 4 lot))
             (buy-date (nth 5 lot))
             (shares (read-string (format "Shares to sell (max %s): " shares-available) shares-available))
             (sell-price (read-string "Sell price per share: "))
             (commission (or (read-string "Commission (default 25): " "25") "25"))
             (cash-accounts '("Assets:NP:ETrade:Cash"
                              "Assets:NP:MY:RBBChecking"
                              "Assets:NP:MY:SBLChecking"))
             (cash-account (completing-read "Deposit to account: " cash-accounts nil t))
             (stock-account (if stock-type
                                (format "Assets:%s:ETrade:%s:%s:%s"
                                        (if (string= currency "USD") "US" "NP")
                                        person stock-type ticker)
                              (format "Assets:%s:ETrade:%s:%s"
                                      (if (string= currency "USD") "US" "NP")
                                      person ticker)))
             (commission-account (format "Expenses:%s:Financial:Commissions" person))
             (pnl-account (format "Income:%s:ETrade:%s:PnL" 
                                  (if (string= currency "USD") "US" "NP") person))
             (proceeds (- (* (string-to-number shares) (string-to-number sell-price))
                          (string-to-number commission)))
             (pnl (- (* (string-to-number shares) 
                        (- (string-to-number sell-price) (string-to-number cost-price)))
                     (string-to-number commission))))
                
        ;; Create accounts if needed
        (unless (beancount-helper--account-exists-p commission-account)
          (when (y-or-n-p (format "Create %s account? " commission-account))
            (beancount-helper--create-account commission-account)))
                
        (unless (beancount-helper--account-exists-p pnl-account)
          (when (y-or-n-p (format "Create %s account? " pnl-account))
            (beancount-helper--create-account pnl-account)))
                
        (let ((transaction (format "%s * \"Sell %sshares of %s%s\"\n  %s  -%s %s {%s %s, %s} @ %s %s\n  %s  %.2f %s\n  %s  %s %s\n  %s  %.2f %s\n"
                                   date 
                                   (if stock-type (concat stock-type " ") "")
                                   ticker
                                   (if (string= person "MY") "" (format " for %s" person))
                                   stock-account shares ticker cost-price currency buy-date sell-price currency
                                   cash-account proceeds currency
                                   commission-account commission currency
                                   pnl-account (- pnl) currency))
              (inhibit-read-only t))
                  
          (beancount-helper--insert-transaction transaction date)
          (message "Sold %s shares of %s for %s - P&L: %.2f %s" shares ticker person pnl currency))))))

(defun beancount-helper--get-stock-lots (ticker)
  "Get all available lots for TICKER across all persons."
  (let ((lots '())
        ;; Match: Assets:NP:ETrade:PERSON:TYPE:TICKER or Assets:NP:ETrade:PERSON:TICKER
        (stock-pattern (format "Assets:[A-Z]+:ETrade:\\([A-Z]+\\)\\(?::\\([A-Z]+\\)\\)?:%s\\s-+\\([0-9.]+\\)\\s-+%s\\s-+{\\([0-9.]+\\)\\s-+\\([A-Z]+\\),\\s-+\\([0-9-]+\\)}"
                               ticker ticker)))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward stock-pattern nil t)
        (let* ((person (match-string 1))
               (type-or-shares (match-string 2))
               (shares (if type-or-shares (match-string 3) (match-string 2)))
               (price (if type-or-shares (match-string 4) (match-string 3)))
               (currency (if type-or-shares (match-string 5) (match-string 4)))
               (date (if type-or-shares (match-string 6) (match-string 5)))
               (stock-type (when (and type-or-shares 
                                      (member type-or-shares '("IPO" "FPO")))
                             type-or-shares)))
          (push (list person stock-type shares price currency date) lots))))
    (nreverse lots)))

;;;###autoload
(defun beancount-helper-dividend ()
  "Record dividend income with person support."
  (interactive)
  (let* ((date (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d")))
         (person (completing-read "Whose account: " beancount-helper-persons nil t nil nil "MY"))
         (ticker (upcase (read-string "Stock ticker (or 'PORTFOLIO' for mixed): ")))
         (amount (read-string "Dividend amount: "))
         (currency (completing-read "Currency: " '("NPR" "USD") nil t nil nil "NPR"))
         (cash-account (format "Assets:%s:ETrade:%s:Cash" 
                               (if (string= currency "USD") "US" "NP") person))
         (dividend-account (format "Income:%s:ETrade:%s:Dividends"
                                   (if (string= currency "USD") "US" "NP") person)))
            
    ;; Create cash account if needed
    (unless (beancount-helper--account-exists-p cash-account)
      (when (y-or-n-p (format "Create %s account? " cash-account))
        (beancount-helper--create-account cash-account)))
            
    ;; Create dividend account if needed
    (unless (beancount-helper--account-exists-p dividend-account)
      (when (y-or-n-p (format "Create %s account? " dividend-account))
        (beancount-helper--create-account dividend-account)))
            
    (let ((transaction (format "%s * \"Dividends on %s%s\"\n  %s  %s %s\n  %s  -%s %s\n"
                               date 
                               (if (string= ticker "PORTFOLIO") "portfolio" ticker)
                               (if (string= person "MY") "" (format " for %s" person))
                               cash-account amount currency
                               dividend-account amount currency))
          (inhibit-read-only t))
              
      (beancount-helper--insert-transaction transaction date)
      (message "Dividend recorded: %s %s from %s for %s" amount currency ticker person))))

;;;###autoload
(defun beancount-helper-bonus-shares ()
  "Record bonus shares received with person support."
  (interactive)
  (let* ((date (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d")))
         (person (completing-read "Whose account: " beancount-helper-persons nil t nil nil "MY"))
         (stock-type (completing-read "Type: " '("Regular" "IPO" "FPO") nil t nil nil "Regular"))
         (ticker (upcase (read-string "Stock ticker: ")))
         (shares (read-string "Number of bonus shares: "))
         (price (read-string "Price per share (0 for free bonus): " "0"))
         (currency (completing-read "Currency: " '("NPR" "USD") nil t nil nil "NPR"))
         (stock-account (if (string= stock-type "Regular")
                            (format "Assets:%s:ETrade:%s:%s" 
                                    (if (string= currency "USD") "US" "NP")
                                    person ticker)
                          (format "Assets:%s:ETrade:%s:%s:%s"
                                  (if (string= currency "USD") "US" "NP")
                                  person stock-type ticker)))
         (bonus-account (format "Income:%s:ETrade:%s:BonusShares"
                                (if (string= currency "USD") "US" "NP") person)))
            
    ;; Create commodity for the ticker if needed
    (beancount-helper--create-commodity ticker)
    
    ;; Create stock account if needed
    (unless (beancount-helper--account-exists-p stock-account)
      (when (y-or-n-p (format "Create %s account? " stock-account))
        (beancount-helper--create-account stock-account)))
    
    ;; Create bonus account if needed
    (unless (beancount-helper--account-exists-p bonus-account)
      (when (y-or-n-p (format "Create %s account? " bonus-account))
        (beancount-helper--create-account bonus-account)))
            
    (let ((transaction (format "%s * \"Bonus shares of %s%s\"\n  %s  %s %s {%s %s, %s}\n  %s  -%s %s\n"
                               date ticker
                               (if (string= person "MY") "" (format " for %s" person))
                               stock-account shares ticker price currency date
                               bonus-account
                               (format "%.2f" (* (string-to-number shares) (string-to-number price)))
                               currency))
          (inhibit-read-only t))
              
      (beancount-helper--insert-transaction transaction date)
      (message "Bonus shares recorded: %s shares of %s for %s" shares ticker person))))

;;;###autoload
(defun beancount-helper-rights-shares ()
  "Record rights shares purchase with person support."
  (interactive)
  (let* ((date (read-string "Date (YYYY-MM-DD): " (format-time-string "%Y-%m-%d")))
         (person (completing-read "Whose account: " beancount-helper-persons nil t nil nil "MY"))
         (ticker (upcase (read-string "Stock ticker: ")))
         (shares (read-string "Number of rights shares: "))
         (price (read-string "Price per share (rights price): "))
         (currency (completing-read "Currency: " '("NPR" "USD") nil t nil nil "NPR"))
         (commission (or (read-string "Commission (default 25): " "25") "25"))
         (broker-accounts '("Assets:NP:MY:RBBChecking"
                            "Assets:NP:MY:SBLChecking"
                            "Assets:NP:MY:Cash"))
         (cash-account (or (completing-read "Pay from account: " broker-accounts nil t) 
                           (car broker-accounts)))
         ;; Rights shares typically go into the same structure as regular shares
         (stock-account (format "Assets:%s:ETrade:%s:RIGHTS:%s" 
                                (if (string= currency "USD") "US" "NP")
                                person ticker))
         (commission-account (format "Expenses:%s:Financial:Commissions" person))
         (total (+ (* (string-to-number shares) (string-to-number price))
                   (string-to-number commission))))
            
    ;; Create commodity for the ticker if needed
    (beancount-helper--create-commodity ticker)
    
    ;; Create stock account if needed
    (unless (beancount-helper--account-exists-p stock-account)
      (when (y-or-n-p (format "Account %s doesn't exist. Create it? " stock-account))
        (beancount-helper--create-account stock-account)))
    
    ;; Create commission account if needed
    (unless (beancount-helper--account-exists-p commission-account)
      (when (y-or-n-p (format "Create %s account? " commission-account))
        (beancount-helper--create-account commission-account)))
            
    (let ((transaction (format "%s * \"Buy RIGHTS shares of %s%s\"\n  %s  -%.2f %s\n  %s  %s %s {%s %s, %s}\n  %s  %s %s\n"
                               date ticker
                               (if (string= person "MY") "" (format " for %s" person))
                               cash-account total currency
                               stock-account shares ticker price currency date
                               commission-account commission currency))
          (inhibit-read-only t))
              
      (beancount-helper--insert-transaction transaction date)
      (message "Rights shares recorded: %s shares of %s at %s %s for %s" 
               shares ticker price currency person))))

(provide 'beancount-helper)
;;; beancount_helper.el ends here
