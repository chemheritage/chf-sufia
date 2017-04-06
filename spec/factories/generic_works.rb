FactoryGirl.define do
  factory :generic_work, aliases: [:work, :public_work], class: GenericWork do
    transient do
      user { FactoryGirl.create(:user) }
      dates_of_work { [DateOfWork.new(start: (1900 + rand(100)).to_s)] }
    end

    title ['Test title']
    visibility Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC

    after(:build) do |work, evaluator|
      work.apply_depositor_metadata(evaluator.user.user_key)

      # unfortunately this does force saving the dates_of_work
      # to fedora, which is slowish.
      work.date_of_work.concat evaluator.dates_of_work
    end

    factory :private_work, aliases: [:public_file] do
      visibility Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    end

    # Not every possible attribute, but a bunch.
    trait :with_complete_metadata do
      sequence(:title) { |n| ["It's Science! pt. #{n}"] }
      author        ['John Smith']
      date_uploaded { DateTime.now }
      date_modified { DateTime.now }
      language      ['English']
      creator       ['creatorcreator']
      contributor   ['contributorcontributor']
      publisher     ['Publisher']
      place_of_creation ["Europe--Holy Roman Empire"]
      subject       ['Celery']
      resource_type ['Text']
      medium        ['Vellum']
      genre_string  ['Manuscripts']
      extent        ["40 pages", "0.75 in. H x 2.5 in. W"]
      series_arrangement ["Series XIV", "Subseries B"]
      description   ["A very nice thing.\r\n\r\nWe really like it"]
      related_url   ['http://example.org/TheRelatedURLLink/']
      rights        ['http://creativecommons.org/publicdomain/mark/1.0/']
      physical_container 'v8|p2|g100'
      additional_title ["Or, There and Back Again q"]
      admin_note    ["This is an admin note"]
      credit_line   ["Courtesy of CHF Collections"]
      division      "Library"
      file_creator  "Lu, Cathleen"

      identifier   ['object-2008.043.002']
      # still does not include inscriptions, or additional_credits,
      # haven't figured those out yet.
    end

    # Image won't resolve, but maybe useful for quick testing? unclear honestly.
    trait :fake_public_image do
      before(:create) do |work, evaluator|
        fileset = FactoryGirl.create(:file_set, :public, user: evaluator.user, title: ['sample.jpg'], label: 'sample.jpg')
        work.ordered_members << fileset
        work.representative = fileset
        work.thumbnail = fileset
      end
    end

    # Real image that will resolve in a browser. It's slow cause it's going
    # through some hydra characterization, stored in fedora, etc. But it's real.
    trait :real_public_image do
      transient do
        image_path { Rails.root + "spec/fixtures/sample.jpg" }
      end
      before(:create) do |work, evaluator|
        fileset = FactoryGirl.create(:file_set, :public,
          user: evaluator.user,
          title: [File.basename(evaluator.image_path)],
          label: File.basename(evaluator.image_path))
        work.ordered_members << fileset
        work.representative = fileset
        work.thumbnail = fileset

        # Try to attach a real image
        IngestFileJob.perform_now(fileset, evaluator.image_path.to_s, evaluator.user)
      end
    end

    # a public work with complete metadata and a real image! Slow.
    factory :full_public_work do
      with_complete_metadata
      real_public_image
    end
  end
end
