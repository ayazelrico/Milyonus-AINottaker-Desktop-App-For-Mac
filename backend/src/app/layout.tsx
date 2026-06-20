import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Milyonus API",
  description: "Backend API for the Milyonus macOS assistant"
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}

