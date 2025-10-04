import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "HabitHive - Build Better Habits Together",
  description: "Transform your habits with friends. Track, compete, and grow together in your personal Hives. Join the sweetest way to build lasting habits.",
  keywords: "habit tracker, social habits, accountability, streak tracking, group habits, productivity",
  openGraph: {
    title: "HabitHive - Build Better Habits Together",
    description: "Transform your habits with friends. Track, compete, and grow together.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={inter.className}>{children}</body>
    </html>
  );
}
