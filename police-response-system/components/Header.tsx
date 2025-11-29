import React from 'react';

const ShieldIcon: React.FC<React.SVGProps<SVGSVGElement>> = (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" {...props}>
        <path fillRule="evenodd" d="M12 1.5a5.25 5.25 0 00-5.25 5.25v3a3 3 0 00-3 3v6.75a3 3 0 003 3h10.5a3 3 0 003-3v-6.75a3 3 0 00-3-3v-3A5.25 5.25 0 0012 1.5zm-3.75 5.25v3a1.5 1.5 0 001.5 1.5h4.5a1.5 1.5 0 001.5-1.5v-3a3.75 3.75 0 10-7.5 0z" clipRule="evenodd" />
    </svg>
);

const UserIcon: React.FC<React.SVGProps<SVGSVGElement>> = (props) => (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" {...props}>
        <path fillRule="evenodd" d="M18.685 19.097A9.723 9.723 0 0021.75 12c0-5.385-4.365-9.75-9.75-9.75S2.25 6.615 2.25 12a9.723 9.723 0 003.065 7.097A9.716 9.716 0 0012 21.75a9.716 9.716 0 006.685-2.653zm-12.54-1.285A7.486 7.486 0 0112 15a7.486 7.486 0 015.855 2.812A8.224 8.224 0 0112 20.25a8.224 8.224 0 01-5.855-2.438zM15.75 9a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z" clipRule="evenodd" />
    </svg>
);


export const Header: React.FC = () => {
  return (
    <header className="bg-red-700 sticky top-0 z-40 border-b border-red-900">
      <div className="container mx-auto px-4 lg:px-6 h-16 flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <div className="flex items-center space-x-2">
             <ShieldIcon className="w-7 h-7 text-white"/>
             <h1 className="text-xl font-bold tracking-tight text-white">
                Police Response System
             </h1>
          </div>
          <nav className="hidden md:flex items-center space-x-2 border-l border-red-500/50 ml-2 pl-4">
            <a href="#" className="px-3 py-2 text-sm font-medium text-white bg-red-800/70 rounded-md">Dashboard</a>
            <a href="#" className="px-3 py-2 text-sm font-medium text-red-200 hover:text-white hover:bg-red-800/70 rounded-md">Settings</a>
            <a href="#" className="px-3 py-2 text-sm font-medium text-red-200 hover:text-white hover:bg-red-800/70 rounded-md">Profile</a>
          </nav>
        </div>
        <div className="flex items-center space-x-3">
            <span className="text-sm text-red-100 hidden sm:inline">Officer Ali</span>
            <div className="w-8 h-8 rounded-full border-2 border-blue-300 p-1">
              <UserIcon className="w-full h-full text-blue-300" />
            </div>
        </div>
      </div>
    </header>
  );
};