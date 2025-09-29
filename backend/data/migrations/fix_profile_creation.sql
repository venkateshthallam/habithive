-- Fix profile creation issues for Apple Sign In users
-- This migration addresses RLS policy and trigger issues

-- 1. Update the trigger function to handle Apple Sign In users properly
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Enhanced logging for debugging
  RAISE LOG 'Creating profile for user: %', new.id;
  RAISE LOG 'User metadata: %', new.raw_user_meta_data;

  INSERT INTO public.profiles (id, display_name)
  VALUES (
    new.id,
    COALESCE(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      'Bee ' || substring(new.id::text, 1, 6)
    )
  )
  ON CONFLICT (id) DO UPDATE SET
    display_name = COALESCE(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      excluded.display_name
    ),
    updated_at = now();

  RAISE LOG 'Successfully created/updated profile for user: %', new.id;
  RETURN new;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'Failed to create profile for user %: % %', new.id, SQLSTATE, SQLERRM;
  RETURN new; -- Don't fail auth if profile creation fails
END $$;

-- 2. Ensure the trigger is properly set up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Add a policy for service role to bypass RLS for profile creation
DROP POLICY IF EXISTS "service_role_all_profiles" ON public.profiles;
CREATE POLICY "service_role_all_profiles" ON public.profiles
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 4. Ensure authenticated users can insert their own profiles
DROP POLICY IF EXISTS "users_insert_own_profile" ON public.profiles;
CREATE POLICY "users_insert_own_profile" ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- 5. Check if we have any orphaned auth users without profiles and create them
INSERT INTO public.profiles (id, display_name, theme)
SELECT
  au.id,
  COALESCE(
    au.raw_user_meta_data->>'full_name',
    au.raw_user_meta_data->>'name',
    'Bee ' || substring(au.id::text, 1, 6)
  ) as display_name,
  'honey' as theme
FROM auth.users au
LEFT JOIN public.profiles p ON au.id = p.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- 6. Verify the policies are correctly set
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;