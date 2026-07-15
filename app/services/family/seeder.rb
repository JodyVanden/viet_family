module Family
  # Builds a canonical sample family (mirrors spec/fixtures/kinship_family.json)
  # for local development and demos. Idempotent: keyed on name.
  module Seeder
    PEOPLE = [
      { name: "Ông Nội",    gender: "male",   birth_date: "1930-03-10", birth_order: 1 },
      { name: "Bà Nội",     gender: "female", birth_date: "1933-06-15", birth_order: 1 },
      { name: "Ông Ngoại",  gender: "male",   birth_date: "1932-02-20", birth_order: 1 },
      { name: "Bà Ngoại",   gender: "female", birth_date: "1935-09-05", birth_order: 1 },
      { name: "Bác Trai",   gender: "male",   birth_date: "1955-01-10", birth_order: 1 },
      { name: "Ba",         gender: "male",   birth_date: "1958-07-22", birth_order: 2 },
      { name: "Chú",        gender: "male",   birth_date: "1961-04-18", birth_order: 3 },
      { name: "Cô",         gender: "female", birth_date: "1964-11-30", birth_order: 4 },
      { name: "Thím",       gender: "female", birth_date: "1963-02-02", birth_order: 1 },
      { name: "Dượng (Cô)", gender: "male",   birth_date: "1962-12-12", birth_order: 1 },
      { name: "Má",         gender: "female", birth_date: "1960-05-14", birth_order: 1 },
      { name: "Cậu",        gender: "male",   birth_date: "1963-08-08", birth_order: 2 },
      { name: "Dì",         gender: "female", birth_date: "1966-03-25", birth_order: 3 },
      { name: "Mợ",         gender: "female", birth_date: "1964-06-06", birth_order: 1 },
      { name: "Dượng (Dì)", gender: "male",   birth_date: "1965-07-07", birth_order: 1 },
      { name: "Anh",        gender: "male",   birth_date: "1980-02-01", birth_order: 1 },
      { name: "Chị",        gender: "female", birth_date: "1983-05-05", birth_order: 2 },
      { name: "Tôi",        gender: "male",   birth_date: "1985-09-09", birth_order: 3 },
      { name: "Em Gái",     gender: "female", birth_date: "1988-12-12", birth_order: 4 },
      { name: "Vợ",         gender: "female", birth_date: "1986-04-04", birth_order: 1 },
      { name: "Ba Vợ",      gender: "male",   birth_date: "1958-03-03", birth_order: 1 },
      { name: "Má Vợ",      gender: "female", birth_date: "1961-10-10", birth_order: 1 },
      { name: "Con Trai",   gender: "male",   birth_date: "2010-01-01", birth_order: 1 },
      { name: "Con Gái",    gender: "female", birth_date: "2013-01-01", birth_order: 2 }
    ].freeze

    # [parent, child]
    PARENTS = [
      [ "Ông Nội", "Bác Trai" ], [ "Bà Nội", "Bác Trai" ],
      [ "Ông Nội", "Ba" ], [ "Bà Nội", "Ba" ],
      [ "Ông Nội", "Chú" ], [ "Bà Nội", "Chú" ],
      [ "Ông Nội", "Cô" ], [ "Bà Nội", "Cô" ],
      [ "Ông Ngoại", "Má" ], [ "Bà Ngoại", "Má" ],
      [ "Ông Ngoại", "Cậu" ], [ "Bà Ngoại", "Cậu" ],
      [ "Ông Ngoại", "Dì" ], [ "Bà Ngoại", "Dì" ],
      [ "Ba", "Anh" ], [ "Má", "Anh" ],
      [ "Ba", "Chị" ], [ "Má", "Chị" ],
      [ "Ba", "Tôi" ], [ "Má", "Tôi" ],
      [ "Ba", "Em Gái" ], [ "Má", "Em Gái" ],
      [ "Ba Vợ", "Vợ" ], [ "Má Vợ", "Vợ" ],
      [ "Tôi", "Con Trai" ], [ "Vợ", "Con Trai" ],
      [ "Tôi", "Con Gái" ], [ "Vợ", "Con Gái" ]
    ].freeze

    SPOUSES = [
      [ "Ông Nội", "Bà Nội" ], [ "Ông Ngoại", "Bà Ngoại" ],
      [ "Ba", "Má" ], [ "Chú", "Thím" ], [ "Cô", "Dượng (Cô)" ],
      [ "Cậu", "Mợ" ], [ "Dì", "Dượng (Dì)" ],
      [ "Tôi", "Vợ" ], [ "Ba Vợ", "Má Vợ" ]
    ].freeze

    module_function

    def seed!
      people = PEOPLE.to_h { |attrs| [ attrs[:name], Person.find_or_create_by!(name: attrs[:name]) { |p| p.assign_attributes(attrs) } ] }

      PARENTS.each do |parent, child|
        Relationship.find_or_create_by!(from_person: people.fetch(parent), to_person: people.fetch(child), kind: "parent")
      end
      SPOUSES.each do |a, b|
        Relationship.find_or_create_by!(from_person: people.fetch(a), to_person: people.fetch(b), kind: "spouse")
      end

      people
    end
  end
end
