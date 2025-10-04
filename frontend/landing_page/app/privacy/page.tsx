export default function Privacy() {
  return (
    <div className="min-h-screen">
      {/* Navigation */}
      <nav className="fixed top-0 w-full bg-white/80 backdrop-blur-md z-50 border-b border-honey-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <a href="/" className="flex items-center space-x-2">
            <div className="w-10 h-10 bg-gradient-to-br from-honey-400 to-hive-500 hexagon flex items-center justify-center">
              <span className="text-2xl">🐝</span>
            </div>
            <span className="text-2xl font-bold">
              Habit<span className="text-gradient">Hive</span>
            </span>
          </a>
          <a href="/" className="text-gray-600 hover:text-honey-600 transition-colors">
            Back to Home
          </a>
        </div>
      </nav>

      {/* Content */}
      <div className="pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <h1 className="text-4xl sm:text-5xl font-bold mb-4">
            Privacy <span className="text-gradient">Policy</span>
          </h1>
          <p className="text-gray-600 mb-8">Last updated: January 2025</p>

          <div className="bg-white rounded-2xl shadow-lg p-8 space-y-8">
            <section>
              <h2 className="text-2xl font-bold mb-4">Introduction</h2>
              <p className="text-gray-700 leading-relaxed">
                Welcome to HabitHive. We respect your privacy and are committed to protecting your personal data.
                This privacy policy will inform you about how we handle your personal data when you use our mobile
                application and tell you about your privacy rights.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Information We Collect</h2>
              <div className="space-y-4">
                <div>
                  <h3 className="text-xl font-semibold mb-2 text-honey-700">Account Information</h3>
                  <p className="text-gray-700">
                    When you create an account, we collect your email address, display name, and profile picture (optional).
                  </p>
                </div>
                <div>
                  <h3 className="text-xl font-semibold mb-2 text-honey-700">Habit Data</h3>
                  <p className="text-gray-700">
                    We collect information about the habits you track, including habit names, emojis, check-in dates,
                    streaks, and completion statistics.
                  </p>
                </div>
                <div>
                  <h3 className="text-xl font-semibold mb-2 text-honey-700">Hive Information</h3>
                  <p className="text-gray-700">
                    When you create or join a Hive, we collect information about Hive membership, shared habits,
                    group progress, and invite codes.
                  </p>
                </div>
                <div>
                  <h3 className="text-xl font-semibold mb-2 text-honey-700">Usage Data</h3>
                  <p className="text-gray-700">
                    We automatically collect information about how you use the app, including features accessed,
                    time spent, and interaction patterns to improve our service.
                  </p>
                </div>
                <div>
                  <h3 className="text-xl font-semibold mb-2 text-honey-700">Device Information</h3>
                  <p className="text-gray-700">
                    We collect device identifiers, operating system version, and push notification tokens to provide
                    app functionality and send notifications.
                  </p>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">How We Use Your Information</h2>
              <ul className="space-y-3">
                {[
                  'To provide and maintain our service',
                  'To enable social features like Hives and leaderboards',
                  'To send you habit reminders and notifications',
                  'To analyze usage patterns and improve our app',
                  'To communicate with you about updates and features',
                  'To ensure security and prevent fraud',
                  'To comply with legal obligations',
                ].map((item, i) => (
                  <li key={i} className="flex items-start gap-3">
                    <span className="w-6 h-6 bg-gradient-to-br from-honey-400 to-hive-500 rounded-full flex items-center justify-center text-white flex-shrink-0 mt-0.5">
                      ✓
                    </span>
                    <span className="text-gray-700">{item}</span>
                  </li>
                ))}
              </ul>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Data Sharing</h2>
              <p className="text-gray-700 leading-relaxed mb-4">
                We do not sell your personal data. We only share your information in the following circumstances:
              </p>
              <ul className="space-y-3">
                {[
                  'With other Hive members - Your habit progress is visible to members of Hives you join',
                  'With service providers - We use third-party services for hosting, analytics, and notifications',
                  'For legal reasons - If required by law or to protect our rights and users',
                  'With your consent - When you explicitly authorize us to share your information',
                ].map((item, i) => (
                  <li key={i} className="flex items-start gap-3">
                    <span className="text-honey-500 flex-shrink-0 mt-1">•</span>
                    <span className="text-gray-700">{item}</span>
                  </li>
                ))}
              </ul>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Data Security</h2>
              <p className="text-gray-700 leading-relaxed">
                We implement industry-standard security measures to protect your personal data. This includes
                encryption in transit and at rest, secure authentication, and regular security audits. However,
                no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Your Rights</h2>
              <p className="text-gray-700 leading-relaxed mb-4">You have the right to:</p>
              <ul className="space-y-3">
                {[
                  'Access your personal data',
                  'Correct inaccurate data',
                  'Request deletion of your data',
                  'Export your data',
                  'Opt-out of notifications',
                  'Withdraw consent at any time',
                ].map((item, i) => (
                  <li key={i} className="flex items-start gap-3">
                    <span className="w-6 h-6 bg-gradient-to-br from-honey-400 to-hive-500 rounded-full flex items-center justify-center text-white flex-shrink-0 mt-0.5">
                      ✓
                    </span>
                    <span className="text-gray-700">{item}</span>
                  </li>
                ))}
              </ul>
              <p className="text-gray-700 leading-relaxed mt-4">
                To exercise these rights, please visit our <a href="/support" className="text-honey-600 hover:underline">Support page</a> or
                contact us directly.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Data Retention</h2>
              <p className="text-gray-700 leading-relaxed">
                We retain your personal data for as long as your account is active or as needed to provide services.
                When you delete your account, we will delete or anonymize your personal data within 30 days, except
                where we are required to retain it for legal purposes.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Children's Privacy</h2>
              <p className="text-gray-700 leading-relaxed">
                HabitHive is not intended for children under 13 years of age. We do not knowingly collect personal
                information from children under 13. If you believe we have collected information from a child under 13,
                please contact us immediately.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">International Data Transfers</h2>
              <p className="text-gray-700 leading-relaxed">
                Your information may be transferred to and processed in countries other than your country of residence.
                We ensure appropriate safeguards are in place to protect your data in compliance with applicable laws.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Changes to This Policy</h2>
              <p className="text-gray-700 leading-relaxed">
                We may update this privacy policy from time to time. We will notify you of any changes by posting the
                new policy on this page and updating the "Last updated" date. Significant changes will be communicated
                via email or in-app notification.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Contact Us</h2>
              <p className="text-gray-700 leading-relaxed mb-4">
                If you have questions about this privacy policy or our data practices, please contact us:
              </p>
              <div className="bg-gradient-to-r from-honey-50 to-hive-50 rounded-xl p-6">
                <p className="text-gray-700">
                  <strong>Email:</strong> privacy@habithive.app<br />
                  <strong>Support:</strong> <a href="/support" className="text-honey-600 hover:underline">Visit our Support page</a>
                </p>
              </div>
            </section>

            <section className="border-t border-gray-200 pt-8">
              <p className="text-sm text-gray-600">
                By using HabitHive, you acknowledge that you have read and understood this Privacy Policy and
                agree to its terms.
              </p>
            </section>
          </div>
        </div>
      </div>

      {/* Footer */}
      <footer className="py-12 px-4 sm:px-6 lg:px-8 bg-white/50 border-t border-honey-200">
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col md:flex-row justify-between items-center gap-6">
            <div className="flex items-center space-x-2">
              <div className="w-10 h-10 bg-gradient-to-br from-honey-400 to-hive-500 hexagon flex items-center justify-center">
                <span className="text-2xl">🐝</span>
              </div>
              <span className="text-2xl font-bold">
                Habit<span className="text-gradient">Hive</span>
              </span>
            </div>
            <div className="flex gap-8 text-gray-600">
              <a href="/" className="hover:text-honey-600 transition-colors">Home</a>
              <a href="/privacy" className="hover:text-honey-600 transition-colors">Privacy</a>
              <a href="/terms" className="hover:text-honey-600 transition-colors">Terms</a>
              <a href="/support" className="hover:text-honey-600 transition-colors">Support</a>
            </div>
            <div className="text-gray-600">
              © 2025 HabitHive. All rights reserved.
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
