import Link from 'next/link';
import Image from 'next/image';

export default function Navigation() {
  return (
    <nav className="bg-gray-950 text-white p-4 border-b border-gray-800">
      <div className="container mx-auto flex justify-between items-center">
        <Link href="/" className="flex items-center space-x-3 group">
          <div className="relative w-10 h-10 transition-transform group-hover:scale-110">
            <Image
              src="/synapse-logo.png"
              alt="Synapse Logo"
              fill
              className="object-contain"
              priority
            />
          </div>
          <span className="text-xl font-bold text-gray-100 group-hover:text-cyan-400 transition-colors">
            Synapse
          </span>
        </Link>
        <div className="space-x-6">
          <Link href="/" className="hover:text-cyan-400 transition-colors">
            Chat
          </Link>
          <Link href="/ingest" className="hover:text-cyan-400 transition-colors">
            Add Knowledge
          </Link>
        </div>
      </div>
    </nav>
  );
}