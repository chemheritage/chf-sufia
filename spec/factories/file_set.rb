# copied from sufia
FactoryGirl.define do
  factory :file_set do
    transient do
      user { FactoryGirl.create(:user) }
      content nil
    end

    after(:build) do |fs, evaluator|
      fs.apply_depositor_metadata evaluator.user.user_key
    end

    after(:create) do |file, evaluator|
      if evaluator.content
        Hydra::Works::UploadFileToFileSet.call(file, evaluator.content)
      end
    end

    trait :public do
      read_groups ["public"]
    end

    trait :registered do
      read_groups ["registered"]
    end

  end
end
