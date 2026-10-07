module Family
  # Builds a fictional demo family (mirrors spec/fixtures/kinship_family.json)
  # for local development, demos, and the tree-layout system specs. Idempotent:
  # keyed on name. The real family's data is private and never committed — see
  # db/seeds.rb, which loads it instead when present.
  module FamilySeeder
    PEOPLE = [
      { name: "Hung Van Tran", gender: "male", birth_date: "1925-05-03", birth_order: 1  },
      { name: "Lan Thi Pham", gender: "female", birth_date: "1926-05-03", birth_order: 1  },
      { name: "Nam Van Tran",    gender: "male", birth_date: "1956-02-12", birth_order: 2 },
      { name: "Suong Thi Tran",    gender: "female", birth_date: "1953-10-05", birth_order: 2 }, # eldest daughter
      { name: "Khoi Van Dinh",    gender: "male", birth_date: "1952-05-10", birth_order: 2 }, # Suong's husband
      { name: "Loc Van Tran",    gender: "male", birth_date: "1960-01-16", birth_order: 2 },
      { name: "Hien Thi Tran",    gender: "female", birth_date: "1965-02-12", birth_order: 2 },
      { name: "Thu Thi Tran",    gender: "female", birth_date: "1968-02-12", birth_order: 2 },
      { name: "Dat Van Tran",    gender: "male", birth_date: "1970-02-12", birth_order: 2 },

      { name: "Phong Van Tran",    gender: "male", birth_date: "1963-02-12", birth_order: 2 },
      { name: "My Thi Vo",    gender: "female", birth_date: "1964-02-12", birth_order: 2 },
      { name: "Lien Thi Tran",    gender: "female", birth_date: "1995-05-02", birth_order: 3 },
      { name: "Minh Van Le",    gender: "male", birth_date: "1995-02-12", birth_order: 3 },
      { name: "Duy Van Tran",    gender: "male", birth_date: "2008-02-12", birth_order: 3 },

      { name: "Yen Thi Tran",   gender: "female",   birth_date: "1990-05-11", birth_order: 3  },
      { name: "Derek Hall",    gender: "male", birth_date: "1986-07-26", birth_order: 3 },

      { name: "Son Van Tran",    gender: "male", birth_date: "1997-11-24", birth_order: 3 },

      { name: "Dao Van Pham",    gender: "male", birth_date: "1930-09-28", death_date: "1960-07-12", birth_order: 1 },
      { name: "Nga Thi Le",    gender: "female", birth_date: "1930-09-28", death_date: "1960-07-12", birth_order: 1 },
      { name: "Hoa Thi Pham",    gender: "female", birth_date: "1956-09-28", death_date: "2015-07-12", birth_order: 2 },
      { name: "Quoc Van Vu",    gender: "male", birth_date: "1958-02-12", birth_order: 2 },
      { name: "Mai Thi Pham",    gender: "female", birth_date: "1958-02-12", birth_order: 2 },
      { name: "Linh Thi Vu",    gender: "female", birth_date: "1958-02-12", birth_order: 3 },
      { name: "Giang Thi Vu",    gender: "female", birth_date: "1958-02-12", birth_order: 3 },
      { name: "Trang Thi Vu",    gender: "female", birth_date: "1958-02-12", birth_order: 3 },
      { name: "Huy Van Vu",    gender: "male", birth_date: "1958-02-12", birth_order: 3 },
      { name: "Phuc Van Vu",    gender: "male", birth_date: "1958-02-12", birth_order: 3 },

      { name: "Hanh Thi Tran",   gender: "female",   birth_date: "1988-08-03", birth_order: 3 },
      { name: "Chris Walker",    gender: "male", birth_date: "1986-12-20", birth_order: 3 },
      { name: "Mia Walker",    gender: "female", birth_date: "2023-11-03", birth_order: 4 },
      { name: "Owen Walker",    gender: "male", birth_date: "2020-09-23", birth_order: 4 }
    ].freeze

    # One block per household: the couple plus their children. Each block expands
    # into a spouse edge between the parents and a parent edge from both parents
    # to every child, so a child can never end up with mismatched parents.
    FAMILIES = [
      { parents: [ "Hung Van Tran", "Lan Thi Pham" ],
        children: [ "Loc Van Tran", "Suong Thi Tran", "Nam Van Tran", "Phong Van Tran", "Hien Thi Tran", "Thu Thi Tran", "Dat Van Tran" ] },
      { parents: [ "Nam Van Tran", "Hoa Thi Pham" ],
        children: [ "Hanh Thi Tran", "Yen Thi Tran", "Son Van Tran" ] },
      { parents: [ "Suong Thi Tran", "Khoi Van Dinh" ] },
      { parents: [ "Phong Van Tran", "My Thi Vo" ],
        children: [ "Lien Thi Tran", "Duy Van Tran" ] },
      { parents: [ "Lien Thi Tran", "Minh Van Le" ] },

      { parents: [ "Dao Van Pham", "Nga Thi Le" ],
        children: [ "Hoa Thi Pham", "Mai Thi Pham" ] },
      { parents: [ "Mai Thi Pham", "Quoc Van Vu" ],
        children: [ "Linh Thi Vu", "Giang Thi Vu", "Trang Thi Vu", "Huy Van Vu", "Phuc Van Vu" ] },

      { parents: [ "Hanh Thi Tran", "Chris Walker" ],
        children: [ "Owen Walker", "Mia Walker" ] },
      { parents: [ "Yen Thi Tran", "Derek Hall" ] }
    ].freeze

    module_function

    def seed!
      people = PEOPLE.to_h { |attrs| [ attrs[:name], Person.find_or_create_by!(name: attrs[:name]) { |p| p.assign_attributes(attrs) } ] }

      FAMILIES.each do |family|
        a, b = family[:parents].map { |name| people.fetch(name) }
        Relationship.find_or_create_by!(from_person: a, to_person: b, kind: "spouse")
        (family[:children] || []).each do |child_name|
          child = people.fetch(child_name)
          [ a, b ].each { |parent| Relationship.find_or_create_by!(from_person: parent, to_person: child, kind: "parent") }
        end
      end

      people
    end
  end
end
