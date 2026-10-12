//
//  PXTimePicker.swift
//  POPOPX (iOS)
//
//  Created by spaced4ndy on 11.05.2023.
//  Copyright © 2025 POPOPX. All rights reserved.
//

// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details
import SwiftUI
import POPOPXSwitch

// MARK: - POPOPX Feature
private let pxTimePickerAnimEnabled = UserDefaults.standard.bool(forKey: "PX_TIME_PICKER_ANIM_ENABLED")

struct PXTimePicker: View {
    @Binding var selection: Int?
    @State var timeUnitsLimits = TimeUnitLimits.defaultUnitsLimits
    @State private var selectedUnit: CustomTimeUnit = .second
    @State private var selectedDuration: Int = 1

    struct TimeUnitLimits {
        var timeUnit: CustomTimeUnit
        var minValue: Int = 1
        var maxValue: Int

        public static func defaultUnitLimits(_ unit: CustomTimeUnit) -> TimeUnitLimits {
            switch unit {
            case .second: return TimeUnitLimits.init(timeUnit: .second, maxValue: PXTimePickerConfig.secondMax)
            case .minute: return TimeUnitLimits.init(timeUnit: .minute, maxValue: PXTimePickerConfig.minuteMax)
            case .hour: return TimeUnitLimits.init(timeUnit: .hour, maxValue: PXTimePickerConfig.hourMax)
            case .day: return TimeUnitLimits.init(timeUnit: .day, maxValue: PXTimePickerConfig.dayMax)
            case .week: return TimeUnitLimits.init(timeUnit: .week, maxValue: PXTimePickerConfig.weekMax)
            case .month: return TimeUnitLimits.init(timeUnit: .month, maxValue: PXTimePickerConfig.monthMax)
            }
        }

        public static var defaultUnitsLimits: [TimeUnitLimits] {[
            defaultUnitLimits(.second),
            defaultUnitLimits(.minute),
            defaultUnitLimits(.hour),
            defaultUnitLimits(.day),
            defaultUnitLimits(.week),
            defaultUnitLimits(.month),
        ]}
    }

    var body: some View {
        HStack(spacing: 0) {
            Group {
                Picker(NSLocalizedString("duration_picker_label", comment: "Duration picker label"), selection: $selectedDuration) {
                    let selectedUnitLimits = timeUnitsLimits.first(where: { $0.timeUnit == selectedUnit }) ?? TimeUnitLimits.defaultUnitLimits(selectedUnit)
                    let selectedUnitValues = Array(selectedUnitLimits.minValue...selectedUnitLimits.maxValue)
                    let values = selectedUnitValues + (selectedUnitValues.contains(selectedDuration) ? [] : [selectedDuration])
                    ForEach(values, id: \.self) { value in
                        Text("\(value)")
                    }
                }
                .accessibilityLabel(Text(NSLocalizedString("Duration value", comment: "Accessibility label for duration picker")))
                Picker(NSLocalizedString("unit_picker_label", comment: "Unit picker label"), selection: $selectedUnit) {
                    ForEach(timeUnitsLimits.map { $0.timeUnit }, id: \.self) { timeUnit in
                        Text(timeUnit.text)
                    }
                }
                .accessibilityLabel(Text(NSLocalizedString("Time unit", comment: "Accessibility label for unit picker")))
            }
            .pickerStyle(.wheel)
            .frame(minWidth: 0)
            .compositingGroup()
            .clipped()
        }
        .onAppear {
            logger.debug("PX: [PXTimePicker.onAppear] selection=\(String(describing: selection))")
            let pxInitialSelection = selection
            if let pxInitialSelection = pxInitialSelection,
               pxInitialSelection > 0 {
                (selectedUnit, selectedDuration) = CustomTimeUnit.toTimeUnit(seconds: pxInitialSelection)
                logger.debug("PX: [PXTimePicker.onAppear] restored unit=\(String(describing: selectedUnit))")
            } else {
                selection = selectedUnit.toSeconds * selectedDuration
            }
        }
        .onChange(of: selectedUnit) {_,  unit in
            logger.debug("PX: [PXTimePicker.onChange] unit changed to \(String(describing: unit))")
            if let maxValue = timeUnitsLimits.first(where: { $0.timeUnit == unit })?.maxValue,
               selectedDuration > maxValue {
                selectedDuration = maxValue
            } else {
                selection = unit.toSeconds * selectedDuration
            }
        }
        .onChange(of: selectedDuration) {_,  duration in
            selection = selectedUnit.toSeconds * duration
        }
        .popopxBranded()
    }
}

extension UIPickerView {
    open override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: super.intrinsicContentSize.height)
    }
}

struct PXTimePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selection: Int?
    var confirmButtonText: LocalizedStringKey
    var confirmButtonAction: () -> Void
    var description: LocalizedStringKey? = nil
    var timeUnitsLimits = PXTimePicker.TimeUnitLimits.defaultUnitsLimits

    var body: some View {
        NavigationStack {
            pxCustomTimePickerView
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(NSLocalizedString("Cancel", comment: "")) {
                            dismiss()
                        }
                        .accessibilityLabel(Text(NSLocalizedString("Cancel time picker", comment: "Accessibility label")))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            confirmButtonAction()
                            dismiss()
                        } label: {
                            Text(confirmButtonText)
                                .fontWeight(.medium)
                        }
                        .disabled(selection == nil)
                        .accessibilityLabel(Text(confirmButtonText))
                    }
                }
        }
    }

    @ViewBuilder
    private var pxCustomTimePickerView: some View {
        VStack(alignment: .leading) {
            List {
                Group {
                    Section(description ?? "") {
                        PXTimePicker(selection: $selection)
                    }
                }
                .listRowInsets(.init(top: 0, leading: PXTimePickerConfig.listHInset, bottom: 0, trailing: PXTimePickerConfig.listHInset))
            }
            .listRowBackground(Color.clear)
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
    }
}

struct PXDropdownTimePicker: View {
    @Binding var selection: Int?
    var label: LocalizedStringKey
    var dropdownValues: [Int?]
    var customPickerConfirmButtonText: LocalizedStringKey
    var customPickerDescription: LocalizedStringKey? = nil
    var customPickerTimeUnitsLimits = PXTimePicker.TimeUnitLimits.defaultUnitsLimits
    @State private var dropdownSelection: DropdownSelection = .dropdownValue(value: nil)
    @State private var showPXTimePicker = false
    @State private var selectedCustomTime: Int? = nil
    @State private var justOpened = true

    enum DropdownSelection: Hashable {
        case dropdownValue(value: Int?)
        case custom
    }

    var body: some View {
        Picker(label, selection: $dropdownSelection) {
            let values: [DropdownSelection] =
            dropdownValues.map { .dropdownValue(value: $0) }
            + (dropdownValues.contains(selection) ? [] : [.dropdownValue(value: selection)])
            + [.custom]
            ForEach(values, id: \.self) { v in
                switch v {
                case let .dropdownValue(value): Text(timeText(value))
                case .custom: Text(NSLocalizedString("custom", comment: "dropdown time picker choice"))
                }
            }
        }
        .accessibilityLabel(Text(label))
        .onAppear {
            logger.debug("PX: [PXDropdownTimePicker.onAppear] initial selection=\(String(describing: selection))")
            dropdownSelection = .dropdownValue(value: selection)
            justOpened = false
        }
        .onChange(of: selection) {_,  v in
            logger.debug("*** .onChange(of: selection)")
            let pxNewValue = v
            dropdownSelection = .dropdownValue(value: pxNewValue)
        }
        .onChange(of: dropdownSelection) {_,  v in
            logger.debug("*** .onChange(of: dropdownSelection)")
            switch v {
            case let .dropdownValue(value): selection = value
            case .custom: showPXTimePicker = true
            }
        }
        .sheet(
            isPresented: $showPXTimePicker,
            onDismiss: {
                dropdownSelection = .dropdownValue(value: selection)
                selectedCustomTime = nil
            }
        ) {
            pxCustomTimePicker
                .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var pxCustomTimePicker: some View {
        PXTimePickerView(
            selection: $selectedCustomTime,
            confirmButtonText: customPickerConfirmButtonText,
            confirmButtonAction: {
                if let time = selectedCustomTime {
                    selection = time
                }
            },
            description: customPickerDescription,
            timeUnitsLimits: customPickerTimeUnitsLimits
        )
        .onAppear {
            selectedCustomTime = selection
        }
    }
}

struct PXWrappedPicker<SelectionValue: Hashable, Content: View, Label: View>: View {
    var selection: Binding<SelectionValue>
    @ViewBuilder var content: () -> Content
    @ViewBuilder var label: () -> Label

    init(_ title: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: @escaping () -> Content) where Label == Text {
        self.selection = selection
        self.content = content
        self.label = { Text(title) }
    }

    init(selection: Binding<SelectionValue>, @ViewBuilder content: @escaping () -> Content, @ViewBuilder label: @escaping () -> Label)  {
        self.selection = selection
        self.content = content
        self.label = label
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            label()
            Spacer()
            Picker(selection: selection, content: content) {
                EmptyView()
            }
            .frame(height: PXTimePickerConfig.pickerFrameHeight)
        }
    }
}

struct PXTimePicker_Previews: PreviewProvider {
    static var previews: some View {
        PXTimePicker(
            selection: Binding.constant(300)
        )
    }
}

// MARK: - POPOPX Config & Tag

private enum PXTimePickerConfig {
    static let secondMax: Int = 120
    static let minuteMax: Int = 120
    static let hourMax: Int = 72
    static let dayMax: Int = 60
    static let weekMax: Int = 52
    static let monthMax: Int = 12
    static let listHInset: CGFloat = 18
    static let pickerFrameHeight: CGFloat = 38
    static let animDuration: Double = 0.22
    static let cornerRadius: CGFloat = 8
}

extension PXTimePicker {
    static let pxComponentTag: String = "PX_CUSTOM_TIME_PICKER"
}
