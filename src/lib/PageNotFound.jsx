import { Link } from 'react-router-dom';

export default function PageNotFound() {
  return (
    <main className="p-6">
      <h1 className="text-xl font-semibold">Page not found</h1>
      <Link className="underline" to="/">Go home</Link>
    </main>
  );
}
