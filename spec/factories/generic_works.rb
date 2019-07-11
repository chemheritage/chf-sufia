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
      work.date_of_work.concat evaluator.dates_of_work if evaluator.dates_of_work.present?
    end

    factory :private_work, aliases: [:public_file] do
      visibility Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    end

    # based on https://digital.sciencehistory.org/concern/generic_works/gh93h041p
    # https://othmerlib.sciencehistory.org/record=b1043559
    factory :oral_history_work do
      title ["Oral history interview with William John Bailey"]
      identifier ["bib-b1043559", "interview-0012"]
      interviewee ['Bailey, William John, 1921-1989']
      interviewer ['Bohning, James J.']
      dates_of_work [DateOfWork.new(start: "1986-06-03")]
      place_of_interview ['University of Maryland, College Park']
      resource_type ['Text']
      genre_string ["Oral histories"]
      extent ['50 pages']
      language ['English']
      division 'Center for Oral History'
      date_uploaded DateTime.now
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
      editor        ['G. Henle Verlag']
      attributed_to ['John Lennon']
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
      credit_line   ["Courtesy of Science History Institute"]
      division      "Library"
      file_creator  "Lu, Cathleen"
      digitization_funder ["Daniel Sanford"]
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
    #
    # Warning this fails on CI since something deep in the stack needs fits
    # installed which we don't have on CI. Sorry. We use it in dev though. :(
    trait :real_public_image do
      transient do
        image_path { Rails.root + "spec/fixtures/sample.jpg" }
        num_images { 1 }
      end
      before(:create) do |work, evaluator|
        evaluator.num_images.times do |i|
          fileset = FactoryGirl.create(:file_set, :public,
            user: evaluator.user,
            title: ["#{File.basename(evaluator.image_path)}_#{i+1}_#{evaluator.title.first}"],
            label: File.basename(evaluator.image_path))
          work.ordered_members << fileset
          work.representative = fileset
          work.thumbnail = fileset

          # Try to attach a real image
          IngestFileJob.perform_now(fileset, evaluator.image_path.to_s, evaluator.user)
        end
      end
    end

    # a public work with complete metadata and a real image! Slow.
    # Warning this fails on CI since it uses :real_public_image and then something
    # deep in the stack needs fits installed which we don't have on CI. Sorry. We use it in dev though. :(
    factory :full_public_work do
      with_complete_metadata
      real_public_image
    end
  end
end
