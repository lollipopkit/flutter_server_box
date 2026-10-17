import { connect } from 'serverbox-desk'

/// This window's desk, connected once before the page draws.
export const desk = await connect()
