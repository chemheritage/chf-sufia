FactoryGirl.define do
  # at the moment all users are staff users
  factory :user, aliases: [:staff_user] do
    sequence(:email) { |n| "user#{n}_#{rand(0..65535).to_s(16)}@example.com" }
    password 'password'

    factory :depositor do
      email 'depositor@example.com'
    end

    trait :admin do
      after(:create) do |u|
        admin_role = Role.find_or_create_by(name: "admin")
        admin_role.users << u
        admin_role.save
      end
    end

  end
end

