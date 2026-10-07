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

    // Lay out the WHOLE family once. Clicking a person never hides anyone — it
    // only re-labels and highlights. Generations are anchored to one person so
    // the layout is stable across clicks.
    this.anchorId = this.defaultFocal()
    this.nodes = this.allNodes
    this.parentEdges = this.parentEdgesValue
    this.spouseEdges = this.spouseEdgesValue

    this.buildIndexes()
    this.positions = new Map()
    this.families = []
    this.nodeEls = new Map()
    this.placed = new Set()
    this.cursorX = 0

    this.buildStage()
    this.resetStage()
    this.layout()
    this.draw()
    this.fitToView()
    this.setupPanZoom()
    this.applyTransform()
    this.highlightPerson(this.anchorId)
  }

  // ---- global (unfiltered) indexes ---------------------------------------

  // Parent/child adjacency over the whole family, used to pick a sensible default
  // focal person before the per-layout indexes are built.
  buildGlobalIndexes() {
    this.allNodes = this.nodesValue
    this.allParentsOf = new Map()
    this.allChildrenOf = new Map()
    const push = (map, k, v) => map.set(k, [ ...(map.get(k) || []), v ])

    this.parentEdgesValue.forEach(([ parent, child ]) => {
      push(this.allParentsOf, child, parent)
      push(this.allChildrenOf, parent, child)
    })
  }

  defaultFocal() {
    if (this.allNodes.length === 0) return null

    const hasGrandparents = (id) => (this.allParentsOf.get(id) || []).some((p) => this.allParentsOf.has(p))
    const rich = this.allNodes.find((n) => hasGrandparents(n.id) && this.allChildrenOf.has(n.id))
    const both = this.allNodes.find((n) => this.allParentsOf.has(n.id) && this.allChildrenOf.has(n.id))
    return (rich || both || this.allNodes[0]).id
  }

  // ---- indexes ------------------------------------------------------------

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
    const gen = new Map([ [ this.anchorId, 0 ] ])
    const queue = [ this.anchorId ]
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
    // Seniority order (oldest first), matching the kinship engine's rule.
    const bySeniority = [ ...new Set(ids) ].sort((x, y) => this.orderIndex.get(x) - this.orderIndex.get(y))

    // A child whose spouse also has parents rendered in the tree links two
    // family blocks together. Move that child to whichever edge of the row
    // faces the in-law family instead of their seniority slot, so the two
    // blocks end up adjacent instead of the in-law block reaching back across
    // this whole row to find them.
    const toStart = []
    const toEnd = []
    const normal = []
    bySeniority.forEach((id) => {
      const edge = this.linkedFamilyEdge(a, id)
      if (edge === "start") toStart.push(id)
      else if (edge === "end") toEnd.push(id)
      else normal.push(id)
    })
    return [ ...toStart, ...normal, ...toEnd ]
  }

  // Which edge of `parent`'s sibling row `child` belongs on, if `child`'s
  // spouse has their own parents in the tree: "end" when this side is laid
  // out first (lower orderIndex than the in-law root), "start" when it's laid
  // out second — so the two blocks meet in the middle. `null` for an ordinary
  // married-in spouse with no parents of their own.
  linkedFamilyEdge(parent, child) {
    const spouse = this.spouseOf.get(child)
    if (!spouse || !this.hasParents(spouse)) return null
    const inLawParent = (this.parentsOf.get(spouse) || [])[0]
    if (inLawParent === undefined) return null
    return this.orderIndex.get(parent) < this.orderIndex.get(inLawParent) ? "end" : "start"
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

  // `spouseOnLeft` faces a married-in spouse away from the blood siblings beside
  // them: true for the leftmost sibling in a row, false for the rightmost, and
  // whichever side has fewer siblings for everyone in between (ties go right,
  // matching the original blood-left/spouse-right default).
  layoutUnit(a, b, spouseOnLeft = false) {
    if (this.placed.has(a)) return this.centerXOf(a, b)
    this.placed.add(a)
    if (b) this.placed.add(b)

    const children = this.unitChildren(a, b)
    if (children.length === 0) return this.placeAtCursor(a, b, spouseOnLeft)

    const centers = children.map((child, i) => {
      const spouse = this.spouseOf.get(child)
      const partner = spouse && !this.placed.has(spouse) && this.hasParents(child) ? spouse : null
      const childSpouseOnLeft = i < children.length - 1 - i
      return this.layoutUnit(child, partner, childSpouseOnLeft)
    })
    const centerX = (Math.min(...centers) + Math.max(...centers)) / 2
    this.placeAtCenter(a, b, centerX, spouseOnLeft)
    return centerX
  }

  unitWidth(b) {
    const C = this.constructor
    return b ? 2 * C.NODE_W + C.COUPLE_GAP : C.NODE_W
  }

  placeAtCursor(a, b, spouseOnLeft = false) {
    const width = this.unitWidth(b)
    const centerX = this.cursorX + width / 2
    this.placeAt(a, b, centerX, spouseOnLeft)
    this.cursorX += width + this.constructor.SIBLING_GAP
    return centerX
  }

  placeAtCenter(a, b, centerX, spouseOnLeft = false) {
    this.placeAt(a, b, centerX, spouseOnLeft)
    this.cursorX = Math.max(this.cursorX, centerX + this.unitWidth(b) / 2 + this.constructor.SIBLING_GAP)
  }

  placeAt(a, b, centerX, spouseOnLeft = false) {
    const C = this.constructor
    const leftX = centerX - this.unitWidth(b) / 2
    const leftPerson = b && spouseOnLeft ? b : a
    const rightPerson = b && spouseOnLeft ? a : b
    this.positions.set(leftPerson, { x: leftX, y: this.yOf(this.level.get(leftPerson)) })
    if (rightPerson) this.positions.set(rightPerson, { x: leftX + C.NODE_W + C.COUPLE_GAP, y: this.yOf(this.level.get(rightPerson)) })
    this.families.push({ a, b, children: this.unitChildren(a, b) })
  }

  centerXOf(a, b) {
    const C = this.constructor
    const pa = this.positions.get(a)
    if (!b) return pa.x + C.NODE_W / 2
    const left = Math.min(pa.x, this.positions.get(b).x)
    return left + C.NODE_W + C.COUPLE_GAP / 2
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
    // The tree is an interactive canvas — don't let panning/clicking select the
    // node text.
    this.element.style.userSelect = "none"
    this.element.style.webkitUserSelect = "none"
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
    this.families.forEach((f) => this.drawCoupleGroup(f)) // behind everything
    this.families.forEach((f) => this.drawFamily(f))
    this.nodes.forEach((n) => this.drawNode(n))
  }

  // A subtle rounded panel behind a married pair so a couple reads as one unit,
  // distinct from the siblings sitting beside them on the same row.
  drawCoupleGroup(f) {
    if (!f.b) return

    const C = this.constructor
    const pa = this.positions.get(f.a)
    const pb = this.positions.get(f.b)
    const left = Math.min(pa.x, pb.x)
    const right = Math.max(pa.x, pb.x) + C.NODE_W
    const pad = 8

    const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect")
    rect.setAttribute("x", left - pad)
    rect.setAttribute("y", pa.y - pad)
    rect.setAttribute("width", right - left + pad * 2)
    rect.setAttribute("height", C.NODE_H + pad)
    rect.setAttribute("rx", 14)
    rect.setAttribute("fill", "#eef2ff") // indigo-50
    this.svg.appendChild(rect)
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
    card.addEventListener("click", (e) => {
      e.stopPropagation()
      this.highlightPerson(n.id)
      this.centerOn(n.id)
    })
    this.world.appendChild(card)
    this.nodeEls.set(n.id, card)
  }

  // Glide the viewport so the given person sits in the middle. Only zooms in if
  // the tree is currently more zoomed out than a readable minimum — otherwise
  // the viewer's own zoom level (set by scrolling) is left alone.
  centerOn(id) {
    const pos = this.positions.get(id)
    if (!pos) return

    const C = this.constructor
    this.scale = Math.max(this.scale, 0.8)
    const cx = pos.x + C.NODE_W / 2
    const cy = pos.y + C.NODE_H / 2
    this.tx = this.element.clientWidth / 2 - cx * this.scale
    this.ty = this.element.clientHeight / 2 - cy * this.scale
    this.animateTo()
  }

  // Clicking the empty background just clears the highlight — it no longer
  // snaps the zoom back out, so the viewer's own pan/zoom is preserved.
  resetView() {
    this.highlightPerson(this.anchorId)
  }

  // Apply the current transform with a brief glide.
  animateTo() {
    this.world.style.transition = "transform 0.35s ease"
    this.applyTransform()
    clearTimeout(this.transitionTimer)
    this.transitionTimer = setTimeout(() => { this.world.style.transition = "" }, 400)
  }

  // ---- labels & lineage highlight ----------------------------------------

  // Re-label everyone from `focalId`'s perspective and bold their blood line.
  // Nobody is added or removed — the layout stays put.
  highlightPerson(focalId) {
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
      hint.textContent = `Showing how ${self ? self.name : ""} addresses everyone — click anyone to switch.`
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
    let downX = 0
    let downY = 0
    this.element.addEventListener("pointerdown", (e) => {
      dragging = true
      this.dragMoved = false
      startX = e.clientX - this.tx; startY = e.clientY - this.ty
      downX = e.clientX; downY = e.clientY
      this.world.style.transition = "" // cancel any glide so dragging is immediate
      this.element.style.cursor = "grabbing"
    })
    // Kept as bound references so disconnect() can remove them (Turbo reconnects
    // this controller, and these live on window, not the element).
    this.onPointerMove = (e) => {
      if (!dragging) return
      if (Math.abs(e.clientX - downX) + Math.abs(e.clientY - downY) > 4) this.dragMoved = true
      this.tx = e.clientX - startX; this.ty = e.clientY - startY; this.applyTransform()
    }
    this.onPointerUp = () => { dragging = false; this.element.style.cursor = "grab" }
    window.addEventListener("pointermove", this.onPointerMove)
    window.addEventListener("pointerup", this.onPointerUp)

    // Clicking the empty background (not a node, which stops propagation, and not
    // the end of a pan) zooms back out to the whole family.
    this.element.addEventListener("click", () => {
      if (!this.dragMoved) this.resetView()
    })
    this.element.addEventListener("wheel", (e) => {
      e.preventDefault()
      const rect = this.element.getBoundingClientRect()
      const pointerX = e.clientX - rect.left
      const pointerY = e.clientY - rect.top
      // Keep the point under the cursor fixed on screen as the scale changes,
      // instead of zooming around the stage's top-left corner.
      const worldX = (pointerX - this.tx) / this.scale
      const worldY = (pointerY - this.ty) / this.scale
      this.scale = Math.min(2.5, Math.max(0.3, this.scale * (e.deltaY < 0 ? 1.1 : 0.9)))
      this.tx = pointerX - worldX * this.scale
      this.ty = pointerY - worldY * this.scale
      this.applyTransform()
    }, { passive: false })
  }

  disconnect() {
    if (this.onPointerMove) window.removeEventListener("pointermove", this.onPointerMove)
    if (this.onPointerUp) window.removeEventListener("pointerup", this.onPointerUp)
    clearTimeout(this.transitionTimer)
  }

  applyTransform() {
    if (this.world) this.world.style.transform = `translate(${this.tx}px, ${this.ty}px) scale(${this.scale})`
  }
}
