//
//  STPPaymentCardTextFieldViewModel.swift
//  Stripe
//
//  Created by Jack Flintermann on 7/21/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

import Foundation
import UIKit

@objc public enum STPCardFieldType: Int {
    case number
    case expiration
    case CVC
    case postalCode
}

public class STPPaymentCardTextFieldViewModel: NSObject {
    private var _cardNumber: String?
    @objc public dynamic var cardNumber: String? {
        get {
            _cardNumber
        }
        set(cardNumber) {
            let sanitizedNumber = STPCardValidator.sanitizedNumericString(for: cardNumber ?? "")
            hasCompleteMetadataForCardNumber = STPBINController.shared.hasBINRanges(forPrefix: sanitizedNumber)
            if hasCompleteMetadataForCardNumber {
                let brand = STPCardValidator.brand(forNumber: sanitizedNumber)
                let maxLength = STPCardValidator.maxLength(for: brand)
                _cardNumber = sanitizedNumber.stp_safeSubstring(to: maxLength)
            } else {
                _cardNumber = sanitizedNumber.stp_safeSubstring(
                    to: Int(STPBINController.shared.maxCardNumberLength()))
            }
        }
    }

    @objc public var rawExpiration: String? {
        get {
            var array: [String] = []
            if expirationMonth != nil && !(expirationMonth == "") {
                array.append(expirationMonth ?? "")
            }

            if STPCardValidator.validationState(forExpirationMonth: expirationMonth ?? "") == .valid
            {
                array.append(expirationYear ?? "")
            }
            return array.joined(separator: "/")
        }
        set(expiration) {
            let sanitizedExpiration = STPCardValidator.sanitizedNumericString(for: expiration ?? "")
            expirationMonth = sanitizedExpiration.stp_safeSubstring(to: 2)
            expirationYear = sanitizedExpiration.stp_safeSubstring(from: 2).stp_safeSubstring(to: 2)
        }
    }

    private var _cvc: String?
    @objc public dynamic var cvc: String? {
        get {
            _cvc
        }
        set(cvc) {
            let maxLength = STPCardValidator.maxCVCLength(for: brand)
            _cvc = STPCardValidator.sanitizedNumericString(for: cvc ?? "").stp_safeSubstring(
                to: Int(maxLength))
        }
    }
    @objc dynamic var postalCodeRequested = false

    public var postalCodeRequired: Bool {
        return postalCodeRequested
            && STPPostalCodeValidator.postalCodeIsRequired(forCountryCode: postalCodeCountryCode)
    }

    private var _postalCode: String?
    public var postalCode: String? {
        get {
            _postalCode
        }
        set(postalCode) {
            _postalCode = STPPostalCodeValidator.formattedSanitizedPostalCode(
                from: postalCode,
                countryCode: postalCodeCountryCode,
                usage: .cardField)
        }
    }

    private var _postalCodeCountryCode: String?
    @objc public dynamic var postalCodeCountryCode: String? {
        get {
            _postalCodeCountryCode
        }
        set(postalCodeCountryCode) {
            _postalCodeCountryCode = postalCodeCountryCode
            postalCode = STPPostalCodeValidator.formattedSanitizedPostalCode(
                from: postalCode,
                countryCode: postalCodeCountryCode,
                usage: .cardField)
        }
    }

    @objc dynamic var brand: STPCardBrand {
        return STPCardValidator.brand(forNumber: cardNumber ?? "")
    }

    @objc dynamic var isValid: Bool {
        return STPCardValidator.validationState(
            forNumber: cardNumber ?? "", validatingCardBrand: true)
            == .valid && hasCompleteMetadataForCardNumber
            && validationStateForExpiration() == .valid
            && validationStateForCVC() == .valid
            && (!postalCodeRequired || validationStateForPostalCode() == .valid)
    }
    @objc dynamic private(set) var hasCompleteMetadataForCardNumber = false

    public var isNumberMaxLength: Bool {
        return (cardNumber?.count ?? 0) == STPBINController.shared.maxCardNumberLength()
    }

    public func defaultPlaceholder() -> String {
        return "4242424242424242"
    }

    public func compressedCardNumber(withPlaceholder placeholder: String?) -> String? {
        var cardNumber = self.cardNumber
        if (cardNumber?.count ?? 0) == 0 {
            cardNumber = placeholder ?? defaultPlaceholder()
        }

        // use the card number format
        let cardNumberFormat = STPCardValidator.cardNumberFormat(forCardNumber: cardNumber ?? "")

        var index = 0
        for segment in cardNumberFormat {
            let segmentLength = Int(segment.uintValue)
            if index + segmentLength >= (cardNumber?.count ?? 0) {
                return cardNumber?.stp_safeSubstring(from: index)
            }
            index += segmentLength
        }

        let length = Int(cardNumberFormat.last?.uintValue ?? 0)
        index = (cardNumber?.count ?? 0) - length

        if index < (cardNumber?.count ?? 0) {
            return cardNumber?.stp_safeSubstring(from: index)
        }

        return nil
    }

    public func validationStateForExpiration() -> STPCardValidationState {
        let monthState = STPCardValidator.validationState(forExpirationMonth: expirationMonth ?? "")
        let yearState = STPCardValidator.validationState(
            forExpirationYear: expirationYear ?? "", inMonth: expirationMonth ?? "")
        if monthState == .valid && yearState == .valid {
            return .valid
        } else if monthState == .invalid || yearState == .invalid {
            return .invalid
        } else {
            return .incomplete
        }
    }

    public func validationStateForCVC() -> STPCardValidationState {
        return STPCardValidator.validationState(forCVC: cvc ?? "", cardBrand: brand)
    }

    public func validationStateForPostalCode() -> STPCardValidationState {
        if (postalCode?.count ?? 0) > 0 {
            return .valid
        } else {
            return .incomplete
        }
    }

    public func validationStateForCardNumber(handler: @escaping (STPCardValidationState) -> Void) {
        STPBINController.shared.retrieveBINRanges(forPrefix: cardNumber ?? "") { _ in
            self.hasCompleteMetadataForCardNumber = STPBINController.shared.hasBINRanges(
                forPrefix: self.cardNumber ?? "")
            handler(
                STPCardValidator.validationState(
                    forNumber: self.cardNumber ?? "", validatingCardBrand: true))
        }
    }

    private var _expirationMonth: String?
    @objc public private(set) var expirationMonth: String? {
        get {
            _expirationMonth
        }
        set {
            // This might contain slashes.
            var sanitizedExpiration = STPCardValidator.sanitizedNumericString(for: newValue ?? "")
            if sanitizedExpiration.count == 1 && !(sanitizedExpiration == "0")
                && !(sanitizedExpiration == "1")
            {
                sanitizedExpiration = "0" + sanitizedExpiration
            }
            _expirationMonth = sanitizedExpiration.stp_safeSubstring(to: 2)
        }
    }
    private var _expirationYear: String?
    @objc public private(set) dynamic var expirationYear: String? {
        get {
            _expirationYear
        }
        set {
            _expirationYear = STPCardValidator.sanitizedNumericString(for: newValue ?? "")
                .stp_safeSubstring(to: 2)

        }
    }

    @objc
    public class func keyPathsForValuesAffectingIsValid() -> Set<String> {
        return Set<String>([
            "cardNumber",
            "expirationMonth",
            "expirationYear",
            "cvc",
            "brand",
            "postalCode",
            "postalCodeRequested",
            "postalCodeCountryCode",
            "hasCompleteMetadataForCardNumber",
        ])
    }
}
