import { Controller } from "@hotwired/stimulus"

// A focus ("hourglass") family tree centred on one person: their ancestors fan
// up (paternal one side, maternal the other), siblings and spouse sit alongside,
// and descendants fan down. Clicking anyone re-centres the tree on them. Every
// label is the Vietnamese term the focal person uses — from a server-computed
// matrix, so the engine is never run on the client.
export default class extends Controller {
  static values = {
    nodes: Array,
    parentEdges: Array,
    spouseEdges: Array,
    terms: Object
  }

  static NODE_W = 112
  static NODE_H = 92
  static SIBLING_GAP = 34
  static COUPLE_GAP = 46
  static V_GAP = 92
  static BLOCK_GAP = 48
  static LINE = "#94a3b8"
  static HILITE = "#4f46e5"

  connect() {
    this.buildGlobalIndexes()
    this.buildStage()
    this.setupPanZoom()
    this.render(this.defaultFocal())
  }

  // ---- global (unfiltered) indexes ---------------------------------------

  buildGlobalIndexes() {
    this.allNodes = this.nodesValue
    this.allParentsOf = new Map()
    this.allChildrenOf = new Map()
    this.allSpouseOf = new Map()
    const push = (map, k, v) => map.set(k, [ ...(map.get(k) || []), v ])

    this.parentEdgesValue.forEach(([ parent, child ]) => {
      push(this.allParentsOf, child, parent)
      push(this.allChildrenOf, parent, child)
    })
    this.spouseEdgesValue.forEach(([ a, b ]) => {
      push(this.allSpouseOf, a, b)
      push(this.allSpouseOf, b, a)
    })
  }

  defaultFocal() {
    const hasGrandparents = (id) => (this.allParentsOf.get(id) || []).some((p) => this.allParentsOf.has(p))
    const rich = this.allNodes.find((n) => hasGrandparents(n.id) && this.allChildrenOf.has(n.id))
    const both = this.allNodes.find((n) => this.allParentsOf.has(n.id) && this.allChildrenOf.has(n.id))
    return (rich || both || this.allNodes[0] || {}).id
  }

  // People shown when centred on `focal`: parents & grandparents, siblings,
  // spouse & the spouse's parents (in-laws), children, and grandchildren.
  visibleSet(focal) {
    const V = new Set([ focal ])
    const get = (m, k) => m.get(k) || [];

    (get(this.allParentsOf, focal)).forEach((p) => {
      V.add(p)
      get(this.allParentsOf, p).forEach((gp) => V.add(gp))
      get(this.allChildrenOf, p).forEach((sib) => V.add(sib))
    })
    const spouses = get(this.allSpouseOf, focal)
    spouses.forEach((sp) => {
      V.add(sp)
      get(this.allParentsOf, sp).forEach((ip) => V.add(ip))
    })
    const kids = new Set()
    ;[ focal, ...spouses ].forEach((id) => get(this.allChildrenOf, id).forEach((k) => { V.add(k); kids.add(k) }))
    kids.forEach((k) => get(this.allChildrenOf, k).forEach((gk) => V.add(gk)))
    return V
  }

  // ---- render a focus -----------------------------------------------------

  render(focalId) {
    if (focalId == null) return
    this.focalId = focalId
    const visible = this.visibleSet(focalId)

    this.nodes = this.allNodes.filter((n) => visible.has(n.id))
    this.parentEdges = this.parentEdgesValue.filter(([ p, c ]) => visible.has(p) && visible.has(c))
    this.spouseEdges = this.spouseEdgesValue.filter(([ a, b ]) => visible.has(a) && visible.has(b))

    this.buildIndexes()
    this.positions = new Map()
    this.families = []
    this.nodeEls = new Map()
    this.placed = new Set()
    this.cursorX = 0

    this.resetStage()
    this.layout()
    this.draw()
    this.applyLabels(focalId)
    this.fitToView()
    this.applyTransform()
  }

  // ---- per-focus indexes --------------------------------------------------

  buildIndexes() {
    const C = this.constructor
    this.nodeById = new Map(this.nodes.map((n) => [ n.id, n ]))
    this.orderIndex = new Map(this.nodes.map((n, i) => [ n.id, i ]))

    this.spouseOf = new Map()
    this.spousesList = new Map()
    this.spouseEdges.forEach(([ a, b ]) => {
      if (!this.spouseOf.has(a)) this.spouseOf.set(a, b)
      if (!this.spouseOf.has(b)) this.spouseOf.set(b, a)
      this.spousesList.set(a, [ ...(this.spousesList.get(a) || []), b ])
      this.spousesList.set(b, [ ...(this.spousesList.get(b) || []), a ])
    })

    this.parentsOf = new Map()
    this.childrenByKey = new Map()
    this.childrenOfPerson = new Map()
    this.parentEdges.forEach(([ parent, child ]) => {
      this.parentsOf.set(child, [ ...(this.parentsOf.get(child) || []), parent ])
      this.childrenOfPerson.set(parent, [ ...(this.childrenOfPerson.get(parent) || []), child ])
    })
    this.parentsOf.forEach((parents, child) => {
      const key = [ ...parents ].sort().join("-")
      this.childrenByKey.set(key, [ ...(this.childrenByKey.get(key) || []), child ])
    })

    this.computeLevels()
    this.yOf = (level) => 24 + level * (C.NODE_H + C.V_GAP)
  }

  // Generation of each visible person as a signed distance from the focal person
  // (parent = +1, spouse = same, child = −1), turned into a top-down row index.
  // This aligns same-generation relatives (e.g. a parent and a parent-in-law)
  // regardless of how deep either side's ancestry is shown.
  computeLevels() {
    const gen = new Map([ [ this.focalId, 0 ] ])
    const queue = [ this.focalId ]
    while (queue.length) {
      const cur = queue.shift()
      const g = gen.get(cur)
      const visit = (id, value) => { if (!gen.has(id)) { gen.set(id, value); queue.push(id) } }
      ;(this.parentsOf.get(cur) || []).forEach((p) => visit(p, g + 1))
      ;(this.childrenOfPerson.get(cur) || []).forEach((c) => visit(c, g - 1))
      ;(this.spousesList.get(cur) || []).forEach((s) => visit(s, g))
    }
    const values = [ ...gen.values() ]
    const maxGen = values.length ? Math.max(...values) : 0
    this.level = new Map()
    this.nodes.forEach((n) => this.level.set(n.id, maxGen - (gen.has(n.id) ? gen.get(n.id) : 0)))
  }

  hasParents(id) {
    return (this.parentsOf.get(id) || []).length > 0
  }

  unitChildren(a, b) {
    const keys = b ? [ [ a, b ].sort().join("-"), String(a), String(b) ] : [ String(a) ]
    const ids = []
    keys.forEach((k) => (this.childrenByKey.get(k) || []).forEach((c) => ids.push(c)))
    return [ ...new Set(ids) ].sort((x, y) => this.orderIndex.get(x) - this.orderIndex.get(y))
  }

  // ---- layout -------------------------------------------------------------

  layout() {
    this.rootUnits().forEach(([ a, b ]) => this.layoutUnit(a, b))
    this.placeLeftovers()
    this.resolveOverlaps()
    this.sizeSvg()
  }

  rootUnits() {
    const units = []
    const used = new Set()
    this.nodes.forEach((n) => {
      if (used.has(n.id) || this.hasParents(n.id)) return
      const spouse = this.spouseOf.get(n.id)
      if (spouse && this.hasParents(spouse)) return
      used.add(n.id)
      if (spouse && !used.has(spouse)) { used.add(spouse); units.push([ n.id, spouse ]) } else { units.push([ n.id, null ]) }
    })
    return units
  }

  layoutUnit(a, b) {
    if (this.placed.has(a)) return this.centerXOf(a, b)
    this.placed.add(a)
    if (b) this.placed.add(b)

    const children = this.unitChildren(a, b)
    if (children.length === 0) return this.placeAtCursor(a, b)

    const centers = children.map((child) => {
      const spouse = this.spouseOf.get(child)
      const partner = spouse && !this.placed.has(spouse) && this.hasParents(child) ? spouse : null
      return this.layoutUnit(child, partner)
    })
    const centerX = (Math.min(...centers) + Math.max(...centers)) / 2
    this.placeAtCenter(a, b, centerX)
    return centerX
  }

  unitWidth(b) {
    const C = this.constructor
    return b ? 2 * C.NODE_W + C.COUPLE_GAP : C.NODE_W
  }

  placeAtCursor(a, b) {
    const width = this.unitWidth(b)
    const centerX = this.cursorX + width / 2
    this.placeAt(a, b, centerX)
    this.cursorX += width + this.constructor.SIBLING_GAP
    return centerX
  }

  placeAtCenter(a, b, centerX) {
    this.placeAt(a, b, centerX)
    this.cursorX = Math.max(this.cursorX, centerX + this.unitWidth(b) / 2 + this.constructor.SIBLING_GAP)
  }

  placeAt(a, b, centerX) {
    const C = this.constructor
    const leftX = centerX - this.unitWidth(b) / 2
    this.positions.set(a, { x: leftX, y: this.yOf(this.level.get(a)) })
    if (b) this.positions.set(b, { x: leftX + C.NODE_W + C.COUPLE_GAP, y: this.yOf(this.level.get(b)) })
    this.families.push({ a, b, children: this.unitChildren(a, b) })
  }

  centerXOf(a, b) {
    const C = this.constructor
    const pa = this.positions.get(a)
    return b ? pa.x + C.NODE_W + C.COUPLE_GAP / 2 : pa.x + C.NODE_W / 2
  }

  placeLeftovers() {
    this.nodes.forEach((n) => { if (!this.positions.has(n.id)) this.placeAtCursor(n.id, null) })
  }

  resolveOverlaps() {
    const C = this.constructor
    const levels = new Map()
    this.positions.forEach((pos, id) => {
      const level = this.level.get(id)
      if (!levels.has(level)) levels.set(level, [])
      levels.get(level).push(id)
    })
    levels.forEach((ids) => {
      ids.sort((a, b) => this.positions.get(a).x - this.positions.get(b).x)
      const seen = new Set()
      const blocks = []
      ids.forEach((id) => {
        if (seen.has(id)) return
        const spouse = this.spouseOf.get(id)
        const coupled = spouse && this.positions.has(spouse) && !seen.has(spouse) &&
          this.level.get(spouse) === this.level.get(id)
        if (coupled) {
          const pair = [ id, spouse ].sort((a, b) => this.positions.get(a).x - this.positions.get(b).x)
          blocks.push(pair); seen.add(id); seen.add(spouse)
        } else { blocks.push([ id ]); seen.add(id) }
      })
      let cursor = -Infinity
      blocks.forEach((block) => {
        const width = block.length === 2 ? 2 * C.NODE_W + C.COUPLE_GAP : C.NODE_W
        const left = Math.max(this.positions.get(block[0]).x, cursor)
        this.positions.get(block[0]).x = left
        if (block.length === 2) this.positions.get(block[1]).x = left + C.NODE_W + C.COUPLE_GAP
        cursor = left + width + C.BLOCK_GAP
      })
    })
  }

  // ---- stage / drawing ----------------------------------------------------

  buildStage() {
    this.element.style.position = "relative"
    this.element.style.cursor = "grab"
    this.world = document.createElement("div")
    this.world.style.cssText = "position:absolute;top:0;left:0;transform-origin:0 0;"
    this.element.appendChild(this.world)
    this.tx = 40; this.ty = 20; this.scale = 1
  }

  resetStage() {
    this.world.innerHTML = ""
    this.svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    this.svg.style.cssText = "position:absolute;top:0;left:0;overflow:visible;pointer-events:none;"
    this.world.appendChild(this.svg)
  }

  sizeSvg() {
    const C = this.constructor
    let maxX = 0
    let maxY = 0
    this.positions.forEach(({ x, y }) => { maxX = Math.max(maxX, x + C.NODE_W); maxY = Math.max(maxY, y + C.NODE_H) })
    this.svg.setAttribute("width", maxX + 40)
    this.svg.setAttribute("height", maxY + 40)
  }

  draw() {
    this.families.forEach((f) => this.drawFamily(f))
    this.nodes.forEach((n) => this.drawNode(n))
  }

  line(x1, y1, x2, y2) {
    const el = document.createElementNS("http://www.w3.org/2000/svg", "line")
    el.setAttribute("x1", x1); el.setAttribute("y1", y1); el.setAttribute("x2", x2); el.setAttribute("y2", y2)
    el.setAttribute("stroke", this.constructor.LINE)
    el.setAttribute("stroke-width", "1.5")
    this.svg.appendChild(el)
    return el
  }

  drawFamily(f) {
    const C = this.constructor
    const pa = this.positions.get(f.a)
    const marriageY = pa.y + C.NODE_H / 2
    f.lineEls = []
    f.childDropEls = new Map()

    let dropX = pa.x + C.NODE_W / 2
    if (f.b) {
      const pb = this.positions.get(f.b)
      const leftX = Math.min(pa.x, pb.x)
      const rightX = Math.max(pa.x, pb.x)
      f.marriageEl = this.line(leftX + C.NODE_W, marriageY, rightX, marriageY)
      dropX = (leftX + C.NODE_W + rightX) / 2
    }
    if (f.children.length === 0) return

    const dropStartY = f.b ? marriageY : pa.y + C.NODE_H
    const childTops = f.children.map((c) => this.positions.get(c).y)
    const busY = Math.min(...childTops) - C.V_GAP / 2
    f.lineEls.push(this.line(dropX, dropStartY, dropX, busY))

    const childCenters = f.children.map((c) => this.positions.get(c).x + C.NODE_W / 2)
    f.lineEls.push(this.line(Math.min(dropX, ...childCenters), busY, Math.max(dropX, ...childCenters), busY))
    f.children.forEach((c) => {
      const cx = this.positions.get(c).x + C.NODE_W / 2
      f.childDropEls.set(c, this.line(cx, busY, cx, this.positions.get(c).y))
    })
  }

  drawNode(n) {
    const C = this.constructor
    const { x, y } = this.positions.get(n.id)
    const card = document.createElement("div")
    card.dataset.nodeId = n.id
    card.style.cssText =
      `position:absolute;left:${x}px;top:${y}px;width:${C.NODE_W}px;` +
      "display:flex;flex-direction:column;align-items:center;text-align:center;cursor:pointer;"

    const avatar = document.createElement("div")
    avatar.style.cssText =
      "width:48px;height:48px;border-radius:9999px;overflow:hidden;display:flex;" +
      "align-items:center;justify-content:center;background:#e0e7ff;color:#4338ca;font-weight:600;" +
      "border:2px solid #fff;box-shadow:0 1px 2px rgba(0,0,0,.1);"
    if (n.portrait_url) {
      const img = document.createElement("img")
      img.src = n.portrait_url; img.alt = n.name
      img.style.cssText = "width:100%;height:100%;object-fit:cover;"
      avatar.appendChild(img)
    } else {
      avatar.textContent = (n.name || "?").charAt(0)
    }

    const name = document.createElement("div")
    name.className = "node-name"
    name.textContent = n.name
    name.style.cssText = "margin-top:4px;font-size:12px;font-weight:600;color:#111827;"

    const term = document.createElement("div")
    term.className = "node-term"
    term.dataset.nodeTerm = n.id
    term.style.cssText = "font-size:12px;color:#4f46e5;min-height:16px;"

    card.append(avatar, name, term)
    card.addEventListener("click", (e) => { e.stopPropagation(); this.render(n.id) })
    this.world.appendChild(card)
    this.nodeEls.set(n.id, card)
  }

  // ---- labels & lineage highlight ----------------------------------------

  applyLabels(focalId) {
    const C = this.constructor
    const terms = this.termsValue[focalId] || {}
    this.nodeEls.forEach((card, nodeId) => {
      const isFocal = nodeId === focalId
      card.style.outline = isFocal ? `2px solid ${C.HILITE}` : "none"
      card.style.borderRadius = "8px"
      card.querySelector(".node-term").textContent = isFocal ? "— bạn —" : (terms[nodeId] || "")
    })
    this.highlightLineage(focalId)

    const hint = document.getElementById("viewpoint-hint")
    if (hint) {
      const self = this.nodeById.get(focalId)
      hint.textContent = `Centred on ${self ? self.name : ""} — click anyone to re-centre the tree on them.`
    }
  }

  highlightLineage(id) {
    const C = this.constructor
    const lineage = this.lineageSet(id)
    this.families.forEach((f) => {
      const style = (el, on) => {
        if (!el) return
        el.setAttribute("stroke", on ? C.HILITE : C.LINE)
        el.setAttribute("stroke-width", on ? "3" : "1.5")
      }
      const parentInLineage = lineage.has(f.a) || (f.b && lineage.has(f.b))
      let any = false
      f.childDropEls.forEach((el, child) => {
        const on = parentInLineage && lineage.has(child)
        if (on) any = true
        style(el, on)
      })
      ;(f.lineEls || []).forEach((el) => style(el, any))
      style(f.marriageEl, parentInLineage)
    })
  }

  lineageSet(id) {
    const set = new Set([ id ])
    const walk = (nextOf) => {
      const stack = [ id ]
      while (stack.length) {
        (nextOf.get(stack.pop()) || []).forEach((next) => { if (!set.has(next)) { set.add(next); stack.push(next) } })
      }
    }
    walk(this.parentsOf)
    walk(this.childrenOfPerson)
    return set
  }

  // ---- fit / pan / zoom ---------------------------------------------------

  fitToView() {
    const contentW = Number(this.svg.getAttribute("width"))
    const contentH = Number(this.svg.getAttribute("height"))
    const boxW = this.element.clientWidth || contentW
    const boxH = this.element.clientHeight || contentH
    const padding = 32
    this.scale = Math.min((boxW - padding) / contentW, (boxH - padding) / contentH, 1)
    this.tx = Math.max(padding / 2, (boxW - contentW * this.scale) / 2)
    this.ty = padding / 2
  }

  setupPanZoom() {
    let dragging = false
    let startX = 0
    let startY = 0
    this.element.addEventListener("pointerdown", (e) => {
      dragging = true; startX = e.clientX - this.tx; startY = e.clientY - this.ty
      this.element.style.cursor = "grabbing"
    })
    window.addEventListener("pointermove", (e) => {
      if (!dragging) return
      this.tx = e.clientX - startX; this.ty = e.clientY - startY; this.applyTransform()
    })
    window.addEventListener("pointerup", () => { dragging = false; this.element.style.cursor = "grab" })
    this.element.addEventListener("wheel", (e) => {
      e.preventDefault()
      this.scale = Math.min(2.5, Math.max(0.3, this.scale * (e.deltaY < 0 ? 1.1 : 0.9)))
      this.applyTransform()
    }, { passive: false })
  }

  applyTransform() {
    if (this.world) this.world.style.transform = `translate(${this.tx}px, ${this.ty}px) scale(${this.scale})`
  }
}
