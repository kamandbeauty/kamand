import StarField from './StarField.jsx';

/**
 * Phone-shaped frame that hosts the app preview. Everything inside uses
 * the `light:` Tailwind variant when the light theme is active.
 */
export default function PhoneFrame({ light, children }) {
  return (
    <div className="relative mx-auto w-full max-w-[400px]">
      <div
        className={`relative flex h-[760px] max-h-[85vh] flex-col overflow-hidden rounded-[40px] border border-white/15 bg-midnight-900 shadow-[0_40px_120px_-30px_rgba(232,199,123,0.25),0_60px_160px_-40px_rgba(0,0,0,0.9)] ${light ? 'light bg-[#eef0f7]' : ''}`}
      >
        <StarField className={light ? 'opacity-20' : 'opacity-90'} density={0.8} />

        {/* status bar */}
        <div className="relative z-10 flex items-center justify-between px-6 pt-3 text-[10px] font-semibold text-slate-300 light:text-slate-500">
          <span>۱۲:۳۰</span>
          <div className="absolute left-1/2 top-2 h-5 w-24 -translate-x-1/2 rounded-full bg-black/80" />
          <span className="flex items-center gap-1">
            <i className="inline-block h-2 w-2 rounded-full bg-emerald-400/70" />
            <i className="inline-block h-2 w-3.5 rounded-sm bg-slate-400/70" />
          </span>
        </div>

        {/* app area */}
        <div className="relative z-10 flex min-h-0 flex-1 flex-col">{children}</div>
      </div>
    </div>
  );
}
