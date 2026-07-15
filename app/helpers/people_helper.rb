module PeopleHelper
  # A round portrait image, or an initials placeholder when none is attached.
  def portrait_tag(person, size: 64)
    if person.portrait.attached?
      image_tag person.portrait, alt: person.name, width: size, height: size,
                class: "rounded-full object-cover bg-gray-100", style: "width:#{size}px;height:#{size}px;"
    else
      content_tag :span, person.name.to_s.first,
                  class: "inline-flex items-center justify-center rounded-full bg-indigo-100 text-indigo-700 font-semibold",
                  style: "width:#{size}px;height:#{size}px;font-size:#{size / 2}px;"
    end
  end

  def life_span(person)
    return nil if person.birth_date.blank? && person.death_date.blank?

    "#{person.birth_date&.year || "?"} – #{person.death_date&.year || ""}".strip
  end
end
