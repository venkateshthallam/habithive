-- Fix missing INSERT policy for profiles table
-- This allows users to create their own profile

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "insert own profile" ON public.profiles;

-- Create INSERT policy for profiles
CREATE POLICY "insert own profile" ON public.profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Also ensure the trigger function has proper permissions
-- Recreate the trigger function with proper security
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (
    new.id,
    COALESCE(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      'Bee ' || substring(new.id::text, 1, 6)
    )
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END $$;

-- Recreate the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Verify policies exist
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;