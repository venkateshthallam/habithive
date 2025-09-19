import SwiftUI
import Combine

struct PhoneAuthView: View {
    @StateObject private var viewModel = PhoneAuthViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPhoneFocused: Bool
    @FocusState private var isOTPFocused: Bool
    
    var body: some View {
        ZStack {
            // Background
            themeManager.currentTheme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView {
                    VStack(spacing: HiveSpacing.xl) {
                        // Progress indicator
                        progressView
                        
                        // Title
                        VStack(spacing: HiveSpacing.sm) {
                            Text(viewModel.showOTPField ? "Verify Your Phone" : "Enter Your Phone")
                                .font(HiveTypography.title2)
                                .foregroundColor(HiveColors.slateText)
                            
                            Text(viewModel.showOTPField ? 
                                 "Enter the 6-digit code we sent to \(viewModel.formattedPhone)" :
                                 "We'll send you a verification code")
                                .font(HiveTypography.body)
                                .foregroundColor(HiveColors.slateText.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, HiveSpacing.lg)
                        
                        // Input fields
                        VStack(spacing: HiveSpacing.md) {
                            if !viewModel.showOTPField {
                                phoneInputView
                            } else {
                                otpInputView
                            }
                            
                            if !viewModel.errorMessage.isEmpty {
                                errorView
                            }
                        }
                        .padding(.horizontal, HiveSpacing.lg)
                        
                        // Continue button
                        continueButton
                            .padding(.horizontal, HiveSpacing.lg)
                        
                        // Test mode hint
                        if APIConfig.testMode {
                            testModeHint
                        }
                        
                        // Resend code option
                        if viewModel.showOTPField {
                            resendCodeView
                        }
                    }
                    .padding(.vertical, HiveSpacing.xl)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if !viewModel.showOTPField {
                isPhoneFocused = true
            }
        }
    }
    
    // MARK: - Components
    
    private var headerView: some View {
        HStack {
            Button(action: {
                if viewModel.showOTPField {
                    viewModel.showOTPField = false
                    viewModel.otpCode = ""
                    viewModel.errorMessage = ""
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(HiveColors.slateText)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Bee logo
            Image(systemName: "hexagon.fill")
                .font(.system(size: 30))
                .foregroundColor(HiveColors.honeyGradientEnd)
                .overlay(
                    Text("🐝")
                        .font(.system(size: 20))
                )
            
            Spacer()
            
            // Placeholder for balance
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, HiveSpacing.md)
        .padding(.vertical, HiveSpacing.sm)
    }
    
    private var progressView: some View {
        HStack(spacing: HiveSpacing.xs) {
            ForEach(0..<2) { index in
                Capsule()
                    .fill(index == 0 || viewModel.showOTPField ? 
                          HiveColors.honeyGradientEnd : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, HiveSpacing.lg)
    }
    
    private var phoneInputView: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.xs) {
            Text("Phone Number")
                .font(HiveTypography.caption)
                .foregroundColor(HiveColors.slateText.opacity(0.7))
            
            HStack {
                Text("🇺🇸 +1")
                    .font(HiveTypography.body)
                    .foregroundColor(HiveColors.slateText)
                    .padding(.leading, HiveSpacing.md)
                
                TextField("(555) 555-1234", text: $viewModel.phoneNumber)
                    .font(HiveTypography.body)
                    .keyboardType(.phonePad)
                    .focused($isPhoneFocused)
                    .onChange(of: viewModel.phoneNumber) { _, newValue in
                        viewModel.formatPhoneNumber()
                    }
            }
            .padding(.vertical, HiveSpacing.md)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(HiveRadius.medium)
        }
    }
    
    private var otpInputView: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.xs) {
            Text("Verification Code")
                .font(HiveTypography.caption)
                .foregroundColor(HiveColors.slateText.opacity(0.7))
            
            HStack(spacing: HiveSpacing.sm) {
                ForEach(0..<6) { index in
                    OTPDigitView(
                        digit: viewModel.getOTPDigit(at: index),
                        isActive: index == viewModel.otpCode.count
                    )
                }
            }
            .overlay(
                TextField("", text: $viewModel.otpCode)
                    .keyboardType(.numberPad)
                    .focused($isOTPFocused)
                    .opacity(0.01)
                    .onChange(of: viewModel.otpCode) { _, newValue in
                        if newValue.count > 6 {
                            viewModel.otpCode = String(newValue.prefix(6))
                        }
                        if newValue.count == 6 {
                            viewModel.verifyOTP()
                        }
                    }
            )
            .onTapGesture {
                isOTPFocused = true
            }
        }
        .onAppear {
            isOTPFocused = true
        }
    }
    
    private var errorView: some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(HiveColors.error)
            
            Text(viewModel.errorMessage)
                .font(HiveTypography.caption)
                .foregroundColor(HiveColors.error)
            
            Spacer()
        }
        .padding(HiveSpacing.sm)
        .background(HiveColors.error.opacity(0.1))
        .cornerRadius(HiveRadius.small)
    }
    
    private var continueButton: some View {
        Button(action: {
            if viewModel.showOTPField {
                viewModel.verifyOTP()
            } else {
                viewModel.sendOTP()
            }
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(viewModel.showOTPField ? "Verify" : "Continue")
                        .font(HiveTypography.headline)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, HiveSpacing.md)
            .background(
                themeManager.currentTheme.primaryGradient
                    .opacity(viewModel.canContinue ? 1 : 0.5)
            )
            .cornerRadius(HiveRadius.large)
        }
        .disabled(!viewModel.canContinue || viewModel.isLoading)
    }
    
    private var testModeHint: some View {
        VStack(spacing: HiveSpacing.xs) {
            Text("🧪 Test Mode Active")
                .font(HiveTypography.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            Text(viewModel.showOTPField ? 
                 "Use code: 123456 or 000000" :
                 "Any phone number will work")
                .font(HiveTypography.caption2)
                .foregroundColor(.blue.opacity(0.8))
        }
        .padding(HiveSpacing.sm)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(HiveRadius.small)
        .padding(.horizontal, HiveSpacing.lg)
    }
    
    private var resendCodeView: some View {
        Button(action: {
            viewModel.resendCode()
        }) {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                
                Text(viewModel.canResend ? 
                     "Resend Code" :
                     "Resend in \(viewModel.resendCountdown)s")
                    .font(HiveTypography.caption)
            }
            .foregroundColor(viewModel.canResend ? 
                           HiveColors.honeyGradientEnd : 
                           HiveColors.slateText.opacity(0.5))
        }
        .disabled(!viewModel.canResend)
    }
}

// MARK: - OTP Digit View
struct OTPDigitView: View {
    let digit: String
    let isActive: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HiveRadius.medium)
                .stroke(isActive ? HiveColors.honeyGradientEnd : Color.gray.opacity(0.3), 
                       lineWidth: isActive ? 2 : 1)
                .frame(width: 45, height: 55)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.medium)
                        .fill(Color.gray.opacity(0.05))
                )
            
            Text(digit)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundColor(HiveColors.slateText)
        }
        .animation(.easeInOut(duration: 0.1), value: isActive)
    }
}

// MARK: - View Model
class PhoneAuthViewModel: ObservableObject {
    @Published var phoneNumber = ""
    @Published var otpCode = ""
    @Published var showOTPField = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var resendCountdown = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var resendTimer: Timer?
    private let apiClient = APIClient.shared
    
    init() {
        // Initialize with test mode hint
        if APIConfig.testMode {
            print("📱 Test mode enabled - Use OTP: 123456 or 000000")
        }
    }
    
    var formattedPhone: String {
        return "+1 \(phoneNumber)"
    }
    
    var canContinue: Bool {
        if showOTPField {
            return otpCode.count == 6
        } else {
            return phoneNumber.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .count >= 10
        }
    }
    
    var canResend: Bool {
        resendCountdown == 0
    }
    
    func formatPhoneNumber() {
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        var formatted = ""
        for (index, char) in cleaned.enumerated() {
            if index == 0 {
                formatted = "("
            }
            if index == 3 {
                formatted += ") "
            }
            if index == 6 {
                formatted += "-"
            }
            if index < 10 {
                formatted += String(char)
            }
        }
        
        phoneNumber = formatted
    }
    
    func getOTPDigit(at index: Int) -> String {
        if index < otpCode.count {
            let stringIndex = otpCode.index(otpCode.startIndex, offsetBy: index)
            return String(otpCode[stringIndex])
        }
        return ""
    }
    
    func sendOTP() {
        isLoading = true
        errorMessage = ""
        
        let cleanPhone = "+1" + phoneNumber
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        if APIConfig.testMode {
            // In test mode, just proceed to OTP
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isLoading = false
                self.showOTPField = true
                self.startResendTimer()
            }
        } else {
            apiClient.sendOTP(phone: cleanPhone)
                .sink(
                    receiveCompletion: { completion in
                        self.isLoading = false
                        if case .failure(let error) = completion {
                            self.errorMessage = error.localizedDescription
                        }
                    },
                    receiveValue: { success in
                        if success {
                            self.showOTPField = true
                            self.startResendTimer()
                        }
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    func verifyOTP() {
        isLoading = true
        errorMessage = ""
        
        let cleanPhone = "+1" + phoneNumber
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        print("🔍 Verifying OTP - Phone: \(cleanPhone), OTP: \(otpCode)")
        
        apiClient.verifyOTP(phone: cleanPhone, otp: otpCode)
            .sink(
                receiveCompletion: { completion in
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        print("❌ OTP verification failed: \(error)")
                        self.errorMessage = "Invalid code. Please try again."
                        self.otpCode = ""
                    }
                },
                receiveValue: { response in
                    print("✅ OTP verification successful! Token: \(response.accessToken)")
                    // Successfully authenticated
                    // The APIClient will handle storing the token and updating isAuthenticated
                    // The app will automatically navigate to MainTabView
                }
            )
            .store(in: &cancellables)
    }
    
    func resendCode() {
        sendOTP()
    }
    
    private func startResendTimer() {
        resendCountdown = 30
        resendTimer?.invalidate()
        
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if self.resendCountdown > 0 {
                self.resendCountdown -= 1
            } else {
                self.resendTimer?.invalidate()
            }
        }
    }
}

#Preview {
    NavigationStack {
        PhoneAuthView()
    }
}