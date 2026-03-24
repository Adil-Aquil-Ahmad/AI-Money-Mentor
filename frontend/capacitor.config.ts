import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.aimoneymentor.app',
  appName: 'AI Money Mentor',
  webDir: 'dist',
  server: {
    // For development, point to Vite dev server
    // url: 'http://YOUR_LOCAL_IP:3000',
    // cleartext: true,
    androidScheme: 'https',
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 2000,
      backgroundColor: '#0a0f1a',
      showSpinner: false,
    },
  },
};

export default config;
