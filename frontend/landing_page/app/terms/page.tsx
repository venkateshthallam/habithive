export default function Terms() {
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
            Terms of <span className="text-gradient">Service</span>
          </h1>
          <p className="text-gray-600 mb-8">Last updated: January 2025</p>

          <div className="bg-white rounded-2xl shadow-lg p-8 space-y-8">
            <section>
              <h2 className="text-2xl font-bold mb-4">Agreement to Terms</h2>
              <p className="text-gray-700 leading-relaxed">
                By accessing or using the HabitHive mobile application ("Service"), you agree to be bound by these
                Terms of Service ("Terms"). If you disagree with any part of these terms, you may not access the Service.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Description of Service</h2>
              <p className="text-gray-700 leading-relaxed mb-4">
                HabitHive is a habit tracking application that enables users to:
              </p>
              <ul className="space-y-3">
                {[
                  'Track personal habits and build streaks',
                  'Create and join social groups called "Hives"',
                  'Share progress with friends and family',
                  'View insights and analytics about habit performance',
                  'Receive notifications and reminders',
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
              <h2 className="text-2xl font-bold mb-4">User Accounts</h2>
              <div className="space-y-4 text-gray-700">
                <p className="leading-relaxed">
                  When you create an account with us, you must provide accurate, complete, and current information.
                  Failure to do so constitutes a breach of the Terms.
                </p>
                <p className="leading-relaxed">
                  You are responsible for safeguarding your account credentials and for any activities or actions
                  under your account. You must immediately notify us of any unauthorized use of your account.
                </p>
                <p className="leading-relaxed">
                  You must be at least 13 years old to use HabitHive. Users under 18 should have parental consent.
                </p>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Acceptable Use</h2>
              <p className="text-gray-700 leading-relaxed mb-4">You agree not to:</p>
              <ul className="space-y-3">
                {[
                  'Use the Service for any illegal purpose or in violation of any laws',
                  'Harass, abuse, or harm other users',
                  'Impersonate any person or entity',
                  'Upload malicious code or attempt to compromise the Service',
                  'Scrape, data mine, or use automated tools to access the Service',
                  'Share inappropriate, offensive, or harmful content',
                  'Violate the privacy of other users',
                  'Attempt to gain unauthorized access to accounts or systems',
                ].map((item, i) => (
                  <li key={i} className="flex items-start gap-3">
                    <span className="text-red-500 flex-shrink-0 mt-1">✗</span>
                    <span className="text-gray-700">{item}</span>
                  </li>
                ))}
              </ul>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">User Content</h2>
              <div className="space-y-4 text-gray-700">
                <p className="leading-relaxed">
                  You retain ownership of any content you submit to HabitHive, including habit names, notes, and
                  profile information ("User Content").
                </p>
                <p className="leading-relaxed">
                  By submitting User Content, you grant us a license to use, store, and display that content as
                  necessary to provide the Service. For content shared within Hives, you grant permission for
                  other Hive members to view that content.
                </p>
                <p className="leading-relaxed">
                  You represent that you have all necessary rights to the User Content you submit and that it
                  does not violate any third-party rights or applicable laws.
                </p>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Hives and Social Features</h2>
              <div className="space-y-4 text-gray-700">
                <p className="leading-relaxed">
                  When you create or join a Hive, you agree that your habit progress and related data will be
                  visible to other Hive members.
                </p>
                <p className="leading-relaxed">
                  Hive creators have the ability to remove members. Members can leave Hives at any time.
                </p>
                <p className="leading-relaxed">
                  You are responsible for maintaining a positive and supportive environment within your Hives.
                  Harassment or abusive behavior may result in account suspension.
                </p>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Intellectual Property</h2>
              <p className="text-gray-700 leading-relaxed">
                The Service and its original content (excluding User Content), features, and functionality are owned
                by HabitHive and are protected by international copyright, trademark, patent, trade secret, and other
                intellectual property laws. You may not copy, modify, distribute, or reverse engineer any part of
                the Service without our express written permission.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Subscriptions and Payments</h2>
              <div className="space-y-4 text-gray-700">
                <p className="leading-relaxed">
                  HabitHive is currently free to use. If we introduce paid features in the future:
                </p>
                <ul className="space-y-2 ml-6 list-disc">
                  <li>Billing will be handled through your App Store account</li>
                  <li>Subscriptions auto-renew unless canceled 24 hours before renewal</li>
                  <li>Refunds are subject to App Store policies</li>
                  <li>We reserve the right to modify pricing with notice</li>
                </ul>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Termination</h2>
              <div className="space-y-4 text-gray-700">
                <p className="leading-relaxed">
                  You may delete your account at any time through the app settings or by contacting support.
                </p>
                <p className="leading-relaxed">
                  We reserve the right to suspend or terminate your account if you violate these Terms or engage
                  in conduct we deem harmful to the Service or other users. We will provide notice when reasonably
                  possible.
                </p>
                <p className="leading-relaxed">
                  Upon termination, your right to use the Service will immediately cease, and we may delete your
                  data in accordance with our Privacy Policy.
                </p>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Disclaimers</h2>
              <div className="bg-yellow-50 border-l-4 border-yellow-500 p-6 rounded-r-lg">
                <p className="text-gray-700 leading-relaxed mb-4">
                  THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS
                  OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
                  PURPOSE, OR NON-INFRINGEMENT.
                </p>
                <p className="text-gray-700 leading-relaxed">
                  HabitHive is a tool to help you track habits. We make no guarantees about the effectiveness of
                  habit tracking or any particular outcomes from using the Service. Your success depends on your
                  own effort and commitment.
                </p>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Limitation of Liability</h2>
              <p className="text-gray-700 leading-relaxed">
                To the maximum extent permitted by law, HabitHive shall not be liable for any indirect, incidental,
                special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred
                directly or indirectly, or any loss of data, use, goodwill, or other intangible losses resulting from:
                (a) your use or inability to use the Service; (b) any unauthorized access to or use of our servers;
                (c) any interruption or cessation of the Service; (d) any bugs, viruses, or other harmful code; or
                (e) any user content or conduct of any third party.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Indemnification</h2>
              <p className="text-gray-700 leading-relaxed">
                You agree to indemnify and hold harmless HabitHive, its officers, directors, employees, and agents
                from any claims, damages, losses, liabilities, and expenses (including legal fees) arising from:
                (a) your use of the Service; (b) your violation of these Terms; (c) your User Content; or
                (d) your violation of any rights of another party.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Changes to Terms</h2>
              <p className="text-gray-700 leading-relaxed">
                We reserve the right to modify these Terms at any time. We will notify users of material changes
                via email or in-app notification. Your continued use of the Service after changes become effective
                constitutes acceptance of the revised Terms.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Changes to Service</h2>
              <p className="text-gray-700 leading-relaxed">
                We reserve the right to modify, suspend, or discontinue the Service (or any part thereof) at any
                time, with or without notice. We will not be liable to you or any third party for any modification,
                suspension, or discontinuance of the Service.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Governing Law</h2>
              <p className="text-gray-700 leading-relaxed">
                These Terms shall be governed by and construed in accordance with the laws of the United States,
                without regard to its conflict of law provisions. Any disputes arising from these Terms or the
                Service shall be resolved in the courts of the United States.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Severability</h2>
              <p className="text-gray-700 leading-relaxed">
                If any provision of these Terms is held to be unenforceable or invalid, such provision will be
                changed and interpreted to accomplish the objectives of such provision to the greatest extent
                possible under applicable law, and the remaining provisions will continue in full force and effect.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Entire Agreement</h2>
              <p className="text-gray-700 leading-relaxed">
                These Terms, together with our Privacy Policy, constitute the entire agreement between you and
                HabitHive regarding the Service and supersede all prior agreements and understandings.
              </p>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-4">Contact Information</h2>
              <p className="text-gray-700 leading-relaxed mb-4">
                If you have questions about these Terms, please contact us:
              </p>
              <div className="bg-gradient-to-r from-honey-50 to-hive-50 rounded-xl p-6">
                <p className="text-gray-700">
                  <strong>Email:</strong> legal@habithive.app<br />
                  <strong>Support:</strong> <a href="/support" className="text-honey-600 hover:underline">Visit our Support page</a>
                </p>
              </div>
            </section>

            <section className="border-t border-gray-200 pt-8">
              <p className="text-sm text-gray-600">
                By using HabitHive, you acknowledge that you have read, understood, and agree to be bound by these
                Terms of Service.
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
