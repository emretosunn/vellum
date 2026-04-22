-- review_reports tablosunda developer/admin kullanıcıların
-- raporları görüntüleyip durum güncelleyebilmesi için RLS politikaları.

ALTER TABLE public.review_reports ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'review_reports'
      AND policyname = 'developers_can_select_review_reports'
  ) THEN
    CREATE POLICY developers_can_select_review_reports
      ON public.review_reports
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM public.profiles p
          WHERE p.id = auth.uid()
            AND (
              p.is_developer = true
              OR p.role = 'admin'
            )
        )
      );
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'review_reports'
      AND policyname = 'developers_can_update_review_reports'
  ) THEN
    CREATE POLICY developers_can_update_review_reports
      ON public.review_reports
      FOR UPDATE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1
          FROM public.profiles p
          WHERE p.id = auth.uid()
            AND (
              p.is_developer = true
              OR p.role = 'admin'
            )
        )
      )
      WITH CHECK (
        EXISTS (
          SELECT 1
          FROM public.profiles p
          WHERE p.id = auth.uid()
            AND (
              p.is_developer = true
              OR p.role = 'admin'
            )
        )
      );
  END IF;
END
$$;

