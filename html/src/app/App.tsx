import { RouterProvider } from 'react-router';
import { router } from './routes';
import { Toaster } from 'sonner';

export default function App() {
  return (
    <div className="min-h-screen bg-[#042142] text-white selection:bg-[#3DE0FC] selection:text-black font-sans antialiased overflow-hidden">
      <RouterProvider router={router} />
      <Toaster theme="dark" position="bottom-right" />
    </div>
  );
}
