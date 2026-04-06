import UIKit

extension KeyboardViewController {

    // MARK: - Build Layout

    func buildLayout() {
        // keyboardView pinned to top/leading/trailing of view
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)
        keyboardHeightConstraint = keyboardView.heightAnchor.constraint(equalToConstant: keyboardHeight)
        NSLayoutConstraint.activate([
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardHeightConstraint,
        ])

        // tabBar
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(tabBar)
        tabBarHeightConstraint = tabBar.heightAnchor.constraint(equalToConstant: tabBarHeight)
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: keyboardView.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor),
            tabBarHeightConstraint,
        ])

        // tabTitleLabel fills tabBar
        tabTitleLabel.textAlignment = .center
        tabTitleLabel.font = .boldSystemFont(ofSize: 14)
        tabTitleLabel.textColor = .white
        tabTitleLabel.isHidden = true
        pinFull(tabTitleLabel, in: tabBar)

        // bottomBar
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            bottomBar.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 47),
        ])
        buildBottomBar()

        // Content views: all fill the area between tabBar and bottomBar
        for v in [tableView, noDittosLabel, addDittoView, numericKeys] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            keyboardView.addSubview(v)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
                v.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor),
                v.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            ])
        }

        // tableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorInset = .zero

        // noDittosLabel
        noDittosLabel.text = "You have no dittos!"
        noDittosLabel.font = .systemFont(ofSize: 26)
        noDittosLabel.textAlignment = .center

        buildAddDittoView()
        buildNumericKeys()
        numericKeys.isHidden = true
    }

    // MARK: - Bottom Bar

    private func buildBottomBar() {
        let sym = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        func symImg(_ name: String) -> UIImage? { UIImage(systemName: name, withConfiguration: sym) }

        nextKeyboardButton.setImage(symImg("globe"), for: .normal)
        dittoButton.setImage(symImg("plus"), for: .normal)
        returnButton.setImage(symImg("return"), for: .normal)
        backspaceButton.setImage(symImg("delete.backward"), for: .normal)
        spaceButton.setTitle("space", for: .normal)

        nextKeyboardButton.addTarget(self, action: #selector(nextKeyboardButtonClicked), for: .touchUpInside)
        dittoButton.addTarget(self, action: #selector(dittoButtonClicked), for: .touchUpInside)
        returnButton.addTarget(self, action: #selector(returnButtonClicked), for: .touchUpInside)
        backspaceButton.addTarget(self, action: #selector(backspaceButtonDown), for: .touchDown)
        backspaceButton.addTarget(self, action: #selector(backspaceButtonUp), for: [.touchUpInside, .touchUpOutside])
        spaceButton.addTarget(self, action: #selector(spaceButtonClicked), for: .touchUpInside)

        let fixedButtons = [nextKeyboardButton, dittoButton, returnButton, backspaceButton]
        for btn in fixedButtons {
            btn.translatesAutoresizingMaskIntoConstraints = false
            bottomBar.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: bottomBar.topAnchor),
                btn.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor),
                btn.widthAnchor.constraint(equalToConstant: 47),
            ])
        }
        spaceButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(spaceButton)

        NSLayoutConstraint.activate([
            nextKeyboardButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            dittoButton.leadingAnchor.constraint(equalTo: nextKeyboardButton.trailingAnchor),
            spaceButton.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            spaceButton.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor),
            spaceButton.leadingAnchor.constraint(equalTo: dittoButton.trailingAnchor),
            spaceButton.trailingAnchor.constraint(equalTo: returnButton.leadingAnchor),
            returnButton.trailingAnchor.constraint(equalTo: backspaceButton.leadingAnchor),
            backspaceButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
        ])
    }

    // MARK: - Add Ditto View

    private func buildAddDittoView() {
        // Category selector button (full width, 44pt)
        setCategoryButtonTitle("Category")
        categoryButton.translatesAutoresizingMaskIntoConstraints = false
        addDittoView.addSubview(categoryButton)
        NSLayoutConstraint.activate([
            categoryButton.topAnchor.constraint(equalTo: addDittoView.topAnchor),
            categoryButton.leadingAnchor.constraint(equalTo: addDittoView.leadingAnchor),
            categoryButton.trailingAnchor.constraint(equalTo: addDittoView.trailingAnchor),
            categoryButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        // Actions row must be added before addDittoTextView so the cross-view constraint has a common ancestor
        addDittoActionsRow.translatesAutoresizingMaskIntoConstraints = false
        addDittoView.addSubview(addDittoActionsRow)

        // Text view (clipboard content)
        addDittoTextView.isEditable = false
        addDittoTextView.isSelectable = false
        addDittoTextView.font = .systemFont(ofSize: 15)
        addDittoTextView.translatesAutoresizingMaskIntoConstraints = false
        addDittoView.addSubview(addDittoTextView)
        NSLayoutConstraint.activate([
            addDittoTextView.topAnchor.constraint(equalTo: categoryButton.bottomAnchor),
            addDittoTextView.leadingAnchor.constraint(equalTo: addDittoView.leadingAnchor, constant: 6),
            addDittoTextView.trailingAnchor.constraint(equalTo: addDittoView.trailingAnchor, constant: -6),
            addDittoTextView.bottomAnchor.constraint(equalTo: addDittoActionsRow.topAnchor),
        ])
        NSLayoutConstraint.activate([
            addDittoActionsRow.leadingAnchor.constraint(equalTo: addDittoView.leadingAnchor),
            addDittoActionsRow.trailingAnchor.constraint(equalTo: addDittoView.trailingAnchor),
            addDittoActionsRow.bottomAnchor.constraint(equalTo: addDittoView.bottomAnchor),
            addDittoActionsRow.heightAnchor.constraint(equalToConstant: 44),
        ])

        let divider = actionsRowDivider
        divider.translatesAutoresizingMaskIntoConstraints = false
        addDittoActionsRow.addSubview(divider)

        pasteButton.setTitle("Paste", for: .normal)
        pasteButton.titleLabel?.font = .systemFont(ofSize: 15)
        pasteButton.addTarget(self, action: #selector(pasteButtonClicked), for: .touchUpInside)
        addDittoButton.setTitle("Add Ditto", for: .normal)
        addDittoButton.titleLabel?.font = .boldSystemFont(ofSize: 15)
        addDittoButton.addTarget(self, action: #selector(addDittoButtonClicked), for: .touchUpInside)

        for btn in [pasteButton, addDittoButton] {
            btn.translatesAutoresizingMaskIntoConstraints = false
            addDittoActionsRow.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: addDittoActionsRow.topAnchor),
                btn.bottomAnchor.constraint(equalTo: addDittoActionsRow.bottomAnchor),
            ])
        }
        NSLayoutConstraint.activate([
            divider.centerXAnchor.constraint(equalTo: addDittoActionsRow.centerXAnchor),
            divider.topAnchor.constraint(equalTo: addDittoActionsRow.topAnchor, constant: 8),
            divider.bottomAnchor.constraint(equalTo: addDittoActionsRow.bottomAnchor, constant: -8),
            divider.widthAnchor.constraint(equalToConstant: 1),
            pasteButton.leadingAnchor.constraint(equalTo: addDittoActionsRow.leadingAnchor),
            pasteButton.trailingAnchor.constraint(equalTo: divider.leadingAnchor),
            addDittoButton.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            addDittoButton.trailingAnchor.constraint(equalTo: addDittoActionsRow.trailingAnchor),
        ])

        // Category picker (fills whole addDittoView when visible, hidden by default)
        categoryPicker.translatesAutoresizingMaskIntoConstraints = false
        categoryPicker.isHidden = true
        addDittoView.addSubview(categoryPicker)
        pinFull(categoryPicker, in: addDittoView)
    }

    // MARK: - Numeric Keys

    private func buildNumericKeys() {
        // 4 rows: 1-2-3, 4-5-6, 7-8-9, .-0
        let digits: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0"]]
        var allRows: [UIView] = []

        for (rowIdx, row) in digits.enumerated() {
            let rowView = UIView()
            rowView.translatesAutoresizingMaskIntoConstraints = false
            var prevCell: UIView?
            for (colIdx, digit) in row.enumerated() {
                let btn = UIButton(type: .system)
                btn.setTitle(digit, for: .normal)
                btn.titleLabel?.font = .preferredFont(forTextStyle: .body)
                btn.addTarget(self, action: #selector(numberClicked(_:)), for: .touchUpInside)
                btn.translatesAutoresizingMaskIntoConstraints = false
                rowView.addSubview(btn)
                if digit == "." { decimalButton = btn }

                NSLayoutConstraint.activate([
                    btn.topAnchor.constraint(equalTo: rowView.topAnchor),
                    btn.bottomAnchor.constraint(equalTo: rowView.bottomAnchor),
                ])

                let isLast = colIdx == row.count - 1
                // Last row: "." is 1/3, "0" is 2/3
                if rowIdx == 3 && digit == "0" {
                    NSLayoutConstraint.activate([
                        btn.leadingAnchor.constraint(equalTo: prevCell!.trailingAnchor),
                        btn.trailingAnchor.constraint(equalTo: rowView.trailingAnchor),
                        btn.widthAnchor.constraint(equalTo: prevCell!.widthAnchor, multiplier: 2),
                    ])
                } else if colIdx == 0 {
                    btn.leadingAnchor.constraint(equalTo: rowView.leadingAnchor).isActive = true
                    if isLast { btn.trailingAnchor.constraint(equalTo: rowView.trailingAnchor).isActive = true }
                } else {
                    NSLayoutConstraint.activate([
                        btn.leadingAnchor.constraint(equalTo: prevCell!.trailingAnchor),
                        btn.widthAnchor.constraint(equalTo: prevCell!.widthAnchor),
                    ])
                    if isLast { btn.trailingAnchor.constraint(equalTo: rowView.trailingAnchor).isActive = true }
                }
                prevCell = btn
            }
            allRows.append(rowView)
            numericKeys.addSubview(rowView)
        }

        // Stack rows vertically with equal heights
        var prevRow: UIView?
        for row in allRows {
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: numericKeys.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: numericKeys.trailingAnchor),
            ])
            if let prev = prevRow {
                NSLayoutConstraint.activate([
                    row.topAnchor.constraint(equalTo: prev.bottomAnchor),
                    row.heightAnchor.constraint(equalTo: prev.heightAnchor),
                ])
            } else {
                row.topAnchor.constraint(equalTo: numericKeys.topAnchor).isActive = true
            }
            prevRow = row
        }
        prevRow?.bottomAnchor.constraint(equalTo: numericKeys.bottomAnchor).isActive = true
    }

    // MARK: - Apply Colors

    func applyColors() {
        let bg = Self.bgColor
        let action = Self.actionColor
        let input = Self.inputColor
        let icon = Self.iconTint

        keyboardView.backgroundColor = bg
        tabBar.backgroundColor = bg
        tableView.backgroundColor = .clear
        noDittosLabel.textColor = .secondaryLabel
        addDittoView.backgroundColor = bg
        bottomBar.backgroundColor = action

        // Add-ditto panel
        categoryButton.backgroundColor = action
        addDittoTextView.backgroundColor = input
        addDittoTextView.textColor = .label
        addDittoActionsRow.backgroundColor = action
        categoryPicker.backgroundColor = bg

        actionsRowDivider.backgroundColor = .separator
        for btn in [pasteButton, addDittoButton] {
            btn.tintColor = icon
        }
        addDittoButton.tintColor = .systemBlue

        // numericKeys
        numericKeys.backgroundColor = bg
        for sub in numericKeys.subviews {
            sub.backgroundColor = bg
            for btn in sub.subviews.compactMap({ $0 as? UIButton }) {
                btn.backgroundColor = input
                btn.setTitleColor(icon, for: .normal)
                btn.layer.cornerRadius = 4
                btn.layer.borderWidth = 0.5
                btn.layer.borderColor = action.resolvedColor(with: traitCollection).cgColor
            }
        }

        // Bottom bar buttons
        for btn in [nextKeyboardButton, dittoButton, returnButton, backspaceButton] {
            btn.backgroundColor = action
            btn.tintColor = icon
        }
        spaceButton.backgroundColor = input
        spaceButton.setTitleColor(icon, for: .normal)

        // Tab arrow notch color
        let arrowColor = bg.resolvedColor(with: traitCollection).cgColor
        selectedTabArrow.fillColor = arrowColor
        selectedTabArrow.strokeColor = arrowColor
    }

    // MARK: - Helpers

    private func pinFull(_ child: UIView, in parent: UIView) {
        child.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(child)
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
        ])
    }
}
